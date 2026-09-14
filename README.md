# nix-devtools

Reusable Nix development tooling built around composable package-set
capabilities and a self-contained flake-parts module.

The public API has two parts:

- `overlays.default` exposes package-set capabilities and concrete tools through
  `pkgs`.
- `flakeModule` provides reusable flake-parts integration.

Repository-specific development policy and tests stay in `flake.nix` and are not
part of the public module.

## Installation

Add `nix-devtools` as a flake input:

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

`overlays.default` is the package-set API.

```nix
pkgs =
  inputs.nixpkgs.legacyPackages.${system}.extend
    inputs.nix-devtools.overlays.default;
```

It exposes reusable development helpers and concrete packages directly through
`pkgs`.

Examples:

```nix
pkgs.mkRustDevHelpers
pkgs.mkGitHooks
pkgs.writeNushellApplication
pkgs.writeNushellScript
pkgs.projectSource

pkgs.diplomat-tool
```

The default overlay also includes `rust-overlay`, so Rust toolchains are
available through:

```nix
pkgs.rust-bin
```

## Rust development

`mkRustDevHelpers` provides shared Crane configuration and reusable Rust checks.

Minimal usage:

```nix
let
  rustDev = pkgs.mkRustDevHelpers {
    inherit pkgs;

    src = pkgs.projectSource {
      projectRoot = ./.;
    };
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

Without an explicit toolchain, Crane uses Rust from the supplied package set.

### Custom Rust toolchain

A custom toolchain may be supplied as either a derivation or a function from a
package set to a derivation.

For example, using `rust-overlay`:

```nix
let
  rustDev = pkgs.mkRustDevHelpers {
    inherit pkgs;

    src = pkgs.projectSource {
      projectRoot = ./.;
    };

    toolchain =
      p:
      p.rust-bin.stable."1.97.1".minimal;
  };
in
{
  checks.test =
    rustDev.checks.test "--workspace";
}
```

Available check builders:

```nix
rustDev.checks.nextest
rustDev.checks.clippy
rustDev.checks.test
rustDev.checks.doc
rustDev.checks.audit
```

Each builder accepts additional Cargo arguments:

```nix
rustDev.checks.nextest "--workspace --all-features"
```

The helpers share vendored dependencies and Crane build artifacts between checks
where possible.

## Project sources

`projectSource` applies the project's `.gitignore` before optionally selecting a
subdirectory.

```nix
src = pkgs.projectSource {
  projectRoot = ./.;
  sourceDir = "crates/server";
};
```

For the whole project:

```nix
src = pkgs.projectSource {
  projectRoot = ./.;
};
```

## Nushell applications

`writeNushellApplication` creates executable Nushell applications with managed
runtime dependencies and environment variables.

```nix
pkgs.writeNushellApplication {
  name = "hello";

  runtimeInputs = [
    pkgs.git
  ];

  runtimeEnv = {
    MESSAGE = "hello";
  };

  text = ''
    print $env.MESSAGE
    git --version
  '';
}
```

For small standalone scripts:

```nix
pkgs.writeNushellScript "hello" ''
  print "hello"
''
```

## Flake module

`flakeModule` provides reusable flake-parts integration.

Import it from the consumer flake:

```nix
{
  imports = [
    inputs.nix-devtools.flakeModule
  ];
}
```

The module is self-contained: implementation dependencies are captured by
`nix-devtools` itself rather than injected into the consumer's module arguments.

Importing it does not import this repository's own tests or development policy.

## Git hooks

The flake module adds the per-system `gitHooks` option.

Hook values are executable files or packages. The module exposes an installer
as:

```text
packages.install-git-hooks
```

A complete example:

```nix
{
  imports = [
    inputs.nix-devtools.flakeModule
  ];

  perSystem =
    {
      system,
      ...
    }:

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

Install the configured hooks with:

```bash
nix run .#install-git-hooks
```

The hook values are executable artifacts, not inline script bodies.

## Development

This repository consumes the same public overlay and flake module that it
exposes to downstream users.

Formatting:

```bash
nix fmt
```

Run all checks:

```bash
nix flake check -L
```

Install repository Git hooks:

```bash
nix run .#install-git-hooks
```

## Design

The architecture keeps three concerns separate:

```text
overlay
    package-set capabilities and tools

flakeModule
    reusable flake integration

flake.nix
    repository-specific policy and tests
```

Provider-owned dependencies are captured lexically when the public flake module
is constructed. They are not published through `_module.args`.

The flake module builds any package universe required by its own implementation
from the pinned `nixpkgs` input and the public overlay. Consumers therefore do
not need to reproduce internal package-set wiring merely to import the module.

The overlay remains the explicit integration point when consumers want
`nix-devtools` capabilities in their own `pkgs` universe.

Local package discovery produces the repository's complete package namespace,
including both derivations and reusable builder functions. Only concrete
derivations are exported through flake `packages`; package-set capabilities stay
in the overlay.

Reusable helpers belong in the package set when they operate on a `pkgs`
universe. Pure Nix functions belong in `lib`.

The goal is to keep dependencies explicit, ambient module state minimal, and the
public surface small and composable.
