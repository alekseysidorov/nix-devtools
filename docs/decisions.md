# Design decisions

This file records the *why* behind the structural choices in `nix-devtools`.
Code shows *what* was built; these notes capture the context, constraints, and
trade-offs that led to each decision so future readers (and agents) do not have to
re-derive them.

The guiding principle, carried from the Nix engineering conventions this project
follows: explicit dependencies, minimal ambient state, one owner per capability,
small public APIs, and no abstraction without a semantic reason.

## 1. Two-part public API: overlay + flake module

- **Context.** The library must serve two different consumers: one that wants
  package-set capabilities in its own `pkgs`, and one that wants flake-parts
  integration.
- **Decision.** Expose exactly two outputs: `overlays.default` (package-set
  capabilities and concrete tools) and `flakeModule` (reusable flake-parts
  integration).
- **Consequence.** A consumer takes only what it needs; the two concerns never
  bleed into each other.

## 2. Repository policy is not part of the public module

- **Context.** This repository has its own tests, git-hook values, and formatting
  policy.
- **Decision.** The exported `flakeModule` contains only the reusable `gitHooks`
  integration. Repository-specific checks (`repositoryChecks`, discovered from
  `./tests`) and the hook *values* live in `flake.nix`, not in the module.
- **Consequence.** Importing the module is hermetic: a downstream consumer does not
  inherit this repository's tests or development policy. This is why
  `flakeModule` and the repository's own `imports` differ.

## 3. One package universe; the `packages` output is derivations only

- **Context.** The local namespace mixes concrete derivations with builder
  functions and helpers.
- **Decision.** Build a single `pkgs` via `localPackagesFor`. Builder functions are
  exposed through `overlays.default`; the flake `packages` output is
  `filterAttrs (_: lib.isDerivation) localPackages`.
- **Consequence.** `diplomat-tool` and `install-git-hooks` are the only flake
  packages. Helpers are reached through the overlay, which is the correct home for
  package-set capabilities.

## 4. Lexical dependency capture; the whole `inputs` set is passed to the module

- **Context.** The module must build its `pkgs` from this repository's public
  overlay, which requires `self`.
- **Decision.** `flakeModule = importApply ./modules inputs` passes the entire
  `inputs` set as static arguments, and `crane` / `rust-advisory-db` are captured
  lexically through `callPackageWith` inside `localPackagesFor` rather than
  published through `_module.args`.
- **Consequence.** `self` is only reachable through the flake's input closure, so
  the whole set is the least-surprising choice. The trade-off is a wider static
  argument set, bought for a self-contained module that leaks no repository-specific
  dependencies into the consumer's module arguments.

## 5. Bootstrap dependencies stay outside the fixed point

- **Context.** The overlay is built while the overlay is being constructed.
- **Decision.** `localOverlay = final: _prev: localPackagesFor { inherit lib;
  pkgs = final; }` takes `lib` from `inputs.nixpkgs.lib` (available before the
  fixed point) and only `pkgs` from `final`.
- **Consequence.** Avoids the classic `final.lib` trap, where evaluating `final.lib`
  would force the fixed point that is currently being built.

## 6. The repository consumes its own public API

- **Context.** The repository develops itself and is the first consumer of its own
  output.
- **Decision.** `perSystem` builds `pkgs` from `inputs.self.overlays.default`, and
  the git-hook module extends the same overlay.
- **Consequence.** The repository exercises the exact path downstream users take,
  so defects in the public API surface in the repository's own checks.

## 7. Nushell helpers keep data and code separate

- **Context.** `writeNushellApplication` and `writeNushellScript` must accept both
  configuration and script bodies.
- **Decision.** `runtimeEnv` is data — serialized to JSON and loaded with
  `load-env` — while `extraConfig` and `text` are raw Nushell code. The generated
  script is syntax-checked with `nu-check` without executing it.
- **Consequence.** Environment values can never be executed as code (no injection),
  while the script body remains a deliberate, documented injection point.

## 8. Rust dev helpers are built on crane

- **Context.** Consumers need shared, hermetic Rust checks.
- **Decision.** `mkRustDevHelpers` is crane-based with `strictDeps = true`, sharing
  one `cargoVendorDir` and one `cargoArtifacts` build across checks. A supplied
  `toolchain` is passed to `craneLib.overrideToolchain` raw.
- **Consequence.** Checks reuse vendored dependencies and artifacts instead of
  building them per check. Because crane already resolves a function-form toolchain
  per platform and exposes the concrete `rustc` / `cargo` / `clippy` / `rustfmt` on
  the returned lib, no separate host-resolved toolchain value is needed; consumers
  read the resolved toolchain from `craneLib`.

## 9. Git hooks are executable artifacts

- **Context.** The `gitHooks` perSystem option maps hook names to values.
- **Decision.** Hook *values* are executable files or packages; the module exposes
  an `install-git-hooks` installer that copies and `chmod +x`es them into
  `.git/hooks`.
- **Consequence.** Hook logic is inspectable and reusable as an artifact, not an
  opaque inline string.

## 10. Test discovery is automatic and outside the module

- **Context.** Tests are repository-specific and should not require manual
  registration.
- **Decision.** `flakeModulesFromDirectoryRecursive ./tests` discovers every
  `*.nix` test module, using a no-op `callPackage` that returns each file's path
  without evaluating it.
- **Consequence.** Adding a test file is enough; the list is never hand-maintained,
  and discovery happens without importing or building the modules.
