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
        src = pkgs.projectSource {
          projectRoot = ./../..;
          sourceDir = "tests/rustDev/fixtures";
        };
      };
    in
    {
      checks.test-rust-dev-nextest = rustDev.checks.nextest "--workspace";
      checks.test-rust-dev-audit = rustDev.checks.audit "";
    };
}
