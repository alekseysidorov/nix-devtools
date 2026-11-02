# nix-devtools

Reusable Nix development tooling exposed as a package overlay and a flake-parts
module.

The public API has two parts:

- `overlays.default` — packages and builders through `pkgs`.
- `flakeModule` — flake-parts integration.

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

It exposes builders (`mkRustDevHelpers`, `mkGitHooks`, `buildMdBook`,
`writeNushellApplication`, `writeNushellScript`, `projectSource`) and concrete
packages (`diplomat-tool`, `nu-lint`, `shell-status`) directly through `pkgs`.
It also includes `rust-overlay`, so Rust toolchains are available as
`pkgs.rust-bin`.

## mdBook documentation

`buildMdBook` builds a book and exposes a `serve` package for the generated
HTML. Add preprocessor packages through `nativeBuildInputs`; configure them in
the book's `book.toml`. The optional `preBuild` hook prepares resources inside
the isolated build directory.

```nix
documentation = pkgs.buildMdBook {
  pname = "project-docs";
  src = ./docs;
  nativeBuildInputs = [ pkgs.mdbook-mermaid ];
  preBuild = ''
    mdbook-mermaid install .
  '';
};
```

Mermaid installs its bundled JavaScript into the build copy; the checkout is not
modified.

Pass project-specific artifacts through `passthru`, for example
`passthru.pdf = myPdfPackage`. These attributes extend the built-in `serve`
package; a supplied `serve` overrides the default. PDF rendering and its browser
dependencies belong to the consuming project.

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
`rustDev.checks.nextest "--workspace --all-features"`. The result also exposes
`craneLib` and `cargoArtifacts` for further Crane-based derivations.

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

## Nushell linting

`pkgs.nu-lint` provides nu-lint 1.7.1, a linter for Nushell scripts.

## Flake module

`flakeModule` provides reusable flake-parts integration:

```nix
{
  imports = [ inputs.nix-devtools.flakeModule ];
}
```

Importing it does not bring in this repository's tests or development policy.

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

## Development

This repository consumes the same public overlay and flake module it exposes to
downstream users:

```bash
nix fmt                  # format
nix flake check -L       # run all checks
nix run .#install-git-hooks
```

Design rationale lives in [`docs/decisions.md`](docs/decisions.md).
