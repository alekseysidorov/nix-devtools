# Design decisions

This file records the _why_ behind the structural choices in `nix-devtools`.
Code shows _what_ was built; these notes capture the context, constraints, and
trade-offs that led to each decision so future readers (and agents) do not have
to re-derive them.

The guiding principle, carried from the Nix engineering conventions this project
follows: explicit dependencies, minimal ambient state, one owner per capability,
small public APIs, and no abstraction without a semantic reason.

## 1. Two-part public API: overlay + flake module

- **Context.** The library must serve two different consumers: one that wants
  package-set capabilities in its own `pkgs`, and one that wants flake-parts
  integration.
- **Decision.** The public API has two surfaces: `overlays.default` (package-set
  capabilities and concrete tools) and `flakeModule` (reusable flake-parts
  integration). The flake also exposes `packages`, `checks`, `formatter`, and
  `lib`, but those are projections and repository policy, not the contract.
- **Consequence.** A consumer takes only what it needs; the two concerns never
  bleed into each other.

## 2. Repository policy is not part of the public module

- **Context.** This repository has its own tests, git-hook values, and
  formatting policy.
- **Decision.** The exported `flakeModule` contains only the reusable `gitHooks`
  integration. Repository-specific checks (`repositoryChecks`, discovered from
  `./tests`) and the hook _values_ live in `flake.nix`, not in the module.
- **Consequence.** Importing the module is hermetic: a downstream consumer does
  not inherit this repository's tests or development policy. This is why
  `flakeModule` and the repository's own `imports` differ.

## 3. One package universe; the `packages` output is derivations only

- **Context.** The local namespace mixes concrete derivations with builder
  functions and helpers.
- **Decision.** Define one package namespace, `localPackages`, from a single
  `pkgs` via `localPackagesFor`. The same definition is used from
  `overlays.default` and, in `perSystem`, to project derivations into the flake
  `packages` output as `filterAttrs (_: lib.isDerivation) localPackages`.
- **Consequence.** `diplomat-tool` and `install-git-hooks` are the only flake
  packages. Helpers are reached through the overlay, which is the correct home
  for package-set capabilities.

## 4. Lexical dependency capture; the whole `inputs` set is passed to the module

- **Context.** The module must build its `pkgs` from this repository's public
  overlay, which requires `self`.
- **Decision.** `flakeModule = importApply ./modules inputs` passes the entire
  `inputs` set as static arguments, and `crane` / `rust-advisory-db` are
  captured lexically through `callPackageWith` inside `localPackagesFor` rather
  than published through `_module.args`.
- **Consequence.** `self` is only reachable through the flake's input closure,
  so the whole set is the least-surprising choice. The trade-off is a wider
  static argument set, bought for a self-contained module that leaks no
  repository-specific dependencies into the consumer's module arguments.

## 5. Bootstrap dependencies stay outside the fixed point

- **Context.** `localOverlay` builds the namespace from `final` — the package
  set currently under construction. Any bootstrap dependency it needs must
  therefore come from outside that fixed point.
- **Decision.** The overlay closes over its bootstrap `lib` instead of reading
  it from `final`:

  ```nix
  # `lib` comes from inputs.nixpkgs.lib, outside the fixed point.
  localOverlay = final: _prev: localPackagesFor {
    inherit lib;
    pkgs = final;
  };
  ```

  Only `pkgs` is taken from `final`.
- **Consequence.** Avoids the classic `final.lib` trap, where evaluating
  `final.lib` would force the fixed point that is currently being built.

## 6. The repository consumes its own public API

- **Context.** The repository develops itself and is the first consumer of its
  own output.
- **Decision.** `perSystem` builds `pkgs` from `inputs.self.overlays.default`,
  and the git-hook module extends the same overlay.
- **Consequence.** The repository exercises the exact path downstream users
  take, so defects in the public API surface in the repository's own checks.

## 7. Nushell helpers keep data and code separate

- **Context.** `writeNushellApplication` must accept both configuration and a
  script body; `writeNushellScript` is the thin `name`/`text`-only helper.
- **Decision.** `runtimeEnv` is data — serialized to JSON and loaded with
  `load-env` — while `extraConfig` and `text` are raw Nushell code. The
  generated script is syntax-checked with `nu-check` without executing it.
- **Consequence.** Environment values can never be executed as code (no
  injection), while the script body remains a deliberate, documented injection
  point.

## 8. Rust dev helpers are built on crane

- **Context.** Consumers need shared, hermetic Rust checks.
- **Decision.** `mkRustDevHelpers` is crane-based with `strictDeps = true`,
  sharing one `cargoVendorDir` and one `cargoArtifacts` build across checks. A
  supplied `toolchain` is passed to `craneLib.overrideToolchain` raw.
- **Consequence.** Checks reuse vendored dependencies and artifacts instead of
  building them per check. Because crane already resolves a function-form
  toolchain per platform and exposes the concrete `rustc` / `cargo` / `clippy` /
  `rustfmt` on the returned lib, no separate host-resolved toolchain value is
  needed; consumers read the resolved toolchain from `craneLib`.

## 9. Git hooks are executable artifacts

- **Context.** The `gitHooks` perSystem option maps hook names to values.
- **Decision.** Hook _values_ are executable files or packages; the module
  exposes an `install-git-hooks` installer that copies and `chmod +x`es them
  into the hooks directory as reported by `git rev-parse --git-path hooks`, so
  `core.hooksPath` is respected.
- **Consequence.** Hook logic is inspectable and reusable as an artifact, not an
  opaque inline string.

## 10. Test discovery is automatic and outside the module

- **Context.** Tests are repository-specific and should not require manual
  registration.
- **Decision.** `flakeModulesFromDirectoryRecursive ./tests` returns test
  modules as plain file paths — a no-op `callPackage` returns each file's path,
  so discovery happens without importing, evaluating, or building the modules.
  The list is never hand-maintained.
- **Gotcha.** Discovery delegates to
  `lib.filesystem.packagesFromDirectoryRecursive`, which special-cases
  `package.nix`: a directory that contains `package.nix` contributes _only_ that
  file and silently ignores its siblings. This is why
  `tests/rustDev/package.nix` is discovered as a single module. `default.nix`
  gets no special treatment. A directory meant to expose several test files must
  therefore not contain a `package.nix`.
- **Consequence.** Adding a test file is enough; ordering is undefined and the
  paths are collected with `lib.collect lib.isPath`.

## 11. Inputs are pinned and deduplicated where possible

- **Context.** Every input that declares its own `nixpkgs` otherwise pulls in a
  separate `nixpkgs` node. Nix keys the lock on node identity, not on the
  source, so even two inputs pinned to the same revision produce two nodes and
  duplicate evaluation and cache entries.
- **Decision.** Pin `nixpkgs` to a release branch (`nixos-26.05`) and make every
  input that declares its own `nixpkgs` follow ours:

  ```nix
  inputs.<name>.inputs.nixpkgs.follows = "nixpkgs";
  ```

  Inputs that do not declare `nixpkgs` — `crane` (no inputs at all) and
  `flake-parts` (tracks only `nixpkgs-lib`) — are left alone.
- **Consequence.** The closure holds a single `nixpkgs` node instead of one per
  input. Note that Nix silently ignores a `follows` clause naming an input the
  dependency does not have, so the policy cannot be enforced mechanically and
  has to be kept by review.
