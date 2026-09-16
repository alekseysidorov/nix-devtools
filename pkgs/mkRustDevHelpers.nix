{
  crane,
  rust-advisory-db,
}:

{
  pkgs,
  src,
  toolchain ? null,
  buildInputs ? [ ],
  nativeBuildInputs ? [ ],
}:

let
  baseCraneLib = crane.mkLib pkgs;
  # Crane's `overrideToolchain` resolves a function-form toolchain per platform and
  # exposes the concrete `rustc`/`cargo`/`clippy`/`rustfmt` on the returned lib, so
  # the raw value is passed through unchanged and consumers read the resolved
  # toolchain from `craneLib` itself.
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
