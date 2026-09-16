# nix-devtools

Reusable Nix development tooling built around composable package-set
capabilities and a self-contained flake-parts module.

The public API has two parts:

- `overlays.default` — package-set capabilities and concrete tools through
  `pkgs`.
- `flakeModule` — reusable flake-parts integration.

Repository-specific policy and tests stay in `flake.nix` and are not part of the
module.

## Design decisions

Each public builder documents its arguments in a doc comment in its source file.
The rationale for the structural choices — public API shape, module hermeticity,
package-universe policy, and toolchain handling — is recorded in
[`docs/decisions.md`](docs/decisions.md).

## Installation

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nix-devtools = {
      url = "github:alekseysidorov/nix-devtools";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

## Overlay

`overlays.default` is the package-set API:

```nix
pkgs =
  inputs.nixpkgs.legacyPackages.${system}.extend
    inputs.nix-devtools.overlays.default;
```

It exposes builders (`mkRustDevHelpers`, `mkGitHooks`,
`writeNushellApplication`, `writeNushellScript`, `projectSource`) and concrete
packages (`diplomat-tool`) directly through `pkgs`. It also includes
`rust-overlay`, so Rust toolchains are available as `pkgs.rust-bin`.

## Rust development

`mkRustDevHelpers` provides shared Crane configuration and reusable Rust checks:

```nix
let
  rustDev = pkgs.mkRustDevHelpers {
    inherit pkgs;
    src = pkgs.projectSource { projectRoot = ./.; };
  };
in
{
  checks = {
    test = rustDev.checks.test "--workspace";
    clippy = rustDev.checks.clippy "--workspace --all-targets";
    doc = rustDev.checks.doc "--workspace";
    audit = rustDev.checks.audit "";
  };
}
```

Check builders are `nextest`, `clippy`, `test`, `doc`, and `audit`; each takes
extra Cargo arguments, e.g.
`rustDev.checks.nextest "--workspace --all-features"`. Dependencies are vendored
and built once and shared across checks, and the result also exposes `craneLib`
and `cargoArtifacts` for further Crane-based derivations.

Without an explicit `toolchain`, Crane uses Rust from the supplied package set.
A custom toolchain may be a derivation or a function from a package set to a
derivation, e.g. with `rust-overlay`:

```nix
toolchain = p: p.rust-bin.stable."1.97.1".minimal;
```

## Project sources

`projectSource` applies the project's `.gitignore` before optionally selecting a
subdirectory. Only the root `.gitignore` is honoured; nested `.gitignore` files
are ignored.

```nix
src = pkgs.projectSource {
  projectRoot = ./.;
  sourceDir = "crates/server"; # optional; omit for the whole project
};
```

## Nushell applications

`writeNushellApplication` creates executable Nushell applications with managed
runtime dependencies and environment variables:

```nix
pkgs.writeNushellApplication {
  name = "hello";
  runtimeInputs = [ pkgs.git ];
  runtimeEnv.MESSAGE = "hello";
  text = ''
    print $env.MESSAGE
    git --version
  '';
}
```

For small standalone scripts,
`pkgs.writeNushellScript "hello" ''print "hello"''` adds no `$PATH`/environment
setup and writes the script to the store path root rather than `/bin`.

## Flake module

`flakeModule` provides reusable flake-parts integration:

```nix
{
  imports = [ inputs.nix-devtools.flakeModule ];
}
```

It is self-contained — implementation dependencies are captured by
`nix-devtools` itself rather than injected into the consumer's module arguments
— and importing it does not bring in this repository's tests or development
policy.

## Git hooks

The flake module adds the per-system `gitHooks` option; `pkgs.mkGitHooks` is the
underlying builder. Hook values are executable files or packages, and the module
exposes an installer as `packages.install-git-hooks`:

```nix
{
  imports = [ inputs.nix-devtools.flakeModule ];

  perSystem =
    { system, ... }:
    let
      pkgs =
        inputs.nixpkgs.legacyPackages.${system}.extend
          inputs.nix-devtools.overlays.default;
    in
    {
      gitHooks = {
        pre-commit = pkgs.writeNushellScript "pre-commit" ''
          nix fmt -- --fail-on-change
        '';
        pre-push = pkgs.writeNushellScript "pre-push" ''
          nix flake check -L
        '';
      };
    };
}
```

Install the configured hooks with `nix run .#install-git-hooks`.

### Why not `git-hooks.nix`?

[`cachix/git-hooks.nix`](https://flake.parts/options/git-hooks-nix.html) is the
batteries-included alternative: it generates a `.pre-commit-config.yaml`, drives
the `pre-commit` runner, ships a large catalogue of ready-made per-file hooks
(`nixfmt`, `deadnix`, `statix`, `clippy`, `rustfmt`, `treefmt`, …), adds a
sandboxed `checks` derivation, and can install hooks from a dev shell.

`gitHooks` here is deliberately minimal: one option plus an installer, with
hooks as executable artifacts you write yourself. That fits this repository
because its hooks are whole-repo commands (`nix fmt`, `nix flake check`) rather
than per-file linters, so the pre-commit file-matching model buys nothing; and
it avoids pulling in a framework, its Python runtime, its own tool set, and a
second configuration language next to Nix. Reach for `git-hooks.nix` when you
want the hook catalogue, per-file filtering, and dev-shell auto-install.

## Development

This repository consumes the same public overlay and flake module it exposes to
downstream users:

```bash
nix fmt                  # format
nix flake check -L       # run all checks
nix run .#install-git-hooks
```
