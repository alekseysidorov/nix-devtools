{
  inputs,
  ...
}:

{
  perSystem =
    { system, ... }:

    let
      pkgs = inputs.nixpkgs.legacyPackages.${system}.extend inputs.self.overlays.default;
      crossPkgs = pkgs.pkgsCross.riscv64.extend inputs.self.overlays.default;
      crossApp = crossPkgs.writeNushellApplication {
        name = "write-nushell-application-cross-test";
        text = ''
          print "cross-build syntax check passed"
        '';
      };

      app = pkgs.writeNushellApplication {
        name = "write-nushell-application-test";

        runtimeEnv.TEST_VALUE = "works";

        text = ''
          if $env.TEST_VALUE != "works" {
            error make { msg: "runtimeEnv was not loaded" }
          }
        '';
      };
    in
    {
      checks.test-write-nushell-application =
        pkgs.runCommand "test-write-nushell-application"
          {
            nativeBuildInputs = [ app ];
          }
          ''
            write-nushell-application-test
            touch $out
          '';

      # The application is checked on the build platform but runs with the
      # target platform's Nu at runtime. This must remain buildable when the
      # target package set is RISC-V and the builder is x86_64.
      checks.test-write-nushell-application-cross =
        pkgs.runCommand "test-write-nushell-application-cross" { }
          ''
            test -x ${crossApp}/bin/write-nushell-application-cross-test
            touch $out
          '';
    };
}
