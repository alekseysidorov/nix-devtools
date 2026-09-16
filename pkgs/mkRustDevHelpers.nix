{
  crane,
  rust-advisory-db,
}:

/**
  Build a set of Crane-based Rust checks for a project.

  Dependencies are vendored and built once and the artifacts are shared by every
  check, so `nix flake check` does not rebuild them per check.

  # Arguments

  `pkgs` (Package set)
  : The package set to build with.

  `src` (Path)
  : The project source; `projectSource` produces a `.gitignore`-filtered one.

  `toolchain` (Derivation or function, _optional_)
  : Toolchain to use instead of the one in `pkgs`. A function of a package set is
    resolved per platform by Crane; the resolved toolchain is exposed as
    `rustc`/`cargo`/`clippy`/`rustfmt` on the returned `craneLib`.

  `buildInputs`, `nativeBuildInputs` (Lists of derivations, _optional_)
  : Extra inputs passed to every check.

  # Result

  `{ craneLib, cargoArtifacts, checks }`. `checks` holds `nextest`, `clippy`,
  `test`, `doc`, and `audit` (preconfigured with the pinned advisory database);
  each takes extra Cargo arguments, e.g. `rustDev.checks.clippy "--workspace"`.

  # Example

  ```nix
  let
    rustDev = mkRustDevHelpers {
      inherit pkgs;
      src = pkgs.projectSource { projectRoot = ./.; };
    };
  in
  {
    clippy = rustDev.checks.clippy "--workspace --all-targets";
    audit = rustDev.checks.audit "";
  }
  ```
*/
{
  pkgs,
  src,
  toolchain ? null,
  buildInputs ? [ ],
  nativeBuildInputs ? [ ],
}:

let
  baseCraneLib = crane.mkLib pkgs;
  craneLib = if toolchain == null then baseCraneLib else baseCraneLib.overrideToolchain toolchain;

  commonArgs = {
    inherit
      src
      buildInputs
      nativeBuildInputs
      ;

    strictDeps = true;

    cargoVendorDir = craneLib.vendorCargoDeps {
      inherit src;
    };
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  checkArgs = commonArgs // {
    inherit cargoArtifacts;
  };

  # Precedence is base `checkArgs`, then the caller's `args`, then fixed `extraArgs`;
  # `extraArgs` wins so module-provided requirements (e.g. audit's `advisory-db`)
  # can never be overridden by user-supplied cargo arguments.
  mkCheck =
    builder: extraArgsName: extraArgs: args:
    builder (
      checkArgs
      // {
        ${extraArgsName} = args;
      }
      // extraArgs
    );
in
{
  inherit
    craneLib
    cargoArtifacts
    ;

  checks = {
    nextest = mkCheck craneLib.cargoNextest "cargoNextestExtraArgs" { };

    clippy = mkCheck craneLib.cargoClippy "cargoClippyExtraArgs" { };

    test = mkCheck craneLib.cargoTest "cargoTestExtraArgs" { };

    doc = mkCheck craneLib.cargoDoc "cargoDocExtraArgs" { };

    audit = mkCheck craneLib.cargoAudit "cargoAuditExtraArgs" {
      advisory-db = rust-advisory-db;
    };
  };
}
