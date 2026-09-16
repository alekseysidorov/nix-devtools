{
  inputs,
  ...
}:

{
  perSystem =
    { system, ... }:

    let
      pkgs = inputs.nixpkgs.legacyPackages.${system}.extend inputs.self.overlays.default;

      rustDev = pkgs.mkRustDevHelpers {
        inherit pkgs;
        # Filter through the repository root, then narrow to the fixture crate.
        src = pkgs.projectSource {
          projectRoot = ./../..;
          sourceDir = "tests/rustDev/fixtures";
        };
      };
    in
    {
      checks.test-rust-dev-nextest = rustDev.checks.nextest "--workspace";
      checks.test-rust-dev-clippy = rustDev.checks.clippy "--workspace --all-targets";
      checks.test-rust-dev-test = rustDev.checks.test "";
      checks.test-rust-dev-doc = rustDev.checks.doc "";
      checks.test-rust-dev-audit = rustDev.checks.audit "";
    };
}
