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
