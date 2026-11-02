{
  lib,
  makeRustPlatform,
  fetchCrate,
  rust-bin,
}:
let
  # nu-parser 0.116 requires Rust 1.96.1, and nu-lint uses
  # `Option::map_or_default`, which is not available in the 1.95 toolchain
  # shipped by the pinned nixpkgs.
  rustToolchain = rust-bin.stable."1.99.1".minimal;

  rustPlatform = makeRustPlatform {
    cargo = rustToolchain;
    rustc = rustToolchain;
  };
in
rustPlatform.buildRustPackage rec {
  pname = "nu-lint";
  version = "1.7.1";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-exIf/Tp7JV01yax1q0VceVun2Jzh8Up1PPVZBHGKQEY=";
  };

  cargoHash = "sha256-5NADmRptlPyB39hRV2opL5jpptdZq/7RnF7McsaYoAY=";

  doCheck = true;

  meta = {
    description = "Linter for Nu shell scripts that helpfully suggests improvements";
    homepage = "https://codeberg.org/wvhulle/nu-lint";
    license = lib.licenses.mit;
    mainProgram = "nu-lint";
    maintainers = [ lib.maintainers.alekseysidorov ];
  };
}
