{
  inputs,
  ...
}:

{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:

    let
      # Model a downstream flake which imports the public module without
      # knowing about its private `localInputs` argument.
      consumer = inputs.flake-parts.lib.mkFlake { inputs = { }; } {
        imports = [
          inputs.flake-parts.flakeModules.modules
          inputs.self.flakeModule
        ];

        systems = [ system ];

        perSystem = {
          gitHooks.pre-commit = pkgs.writeShellScript "pre-commit" ''
            exit 0
          '';
        };
      };

      packages = consumer.packages.${system};
    in
    {
      checks.test-public-flake-module-consumer =
        assert packages ? install-git-hooks;

        pkgs.runCommand "test-public-flake-module-consumer" { } ''
          touch $out
        '';
    };
}
