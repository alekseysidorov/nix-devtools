{ inputs, ... }:

{
  lib,
  flake-parts-lib,
  ...
}:

{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      config,
      system,
      ...
    }:

    let
      pkgs = inputs.nixpkgs.legacyPackages.${system}.extend inputs.self.overlays.default;
    in
    {
      options.gitHooks = lib.mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.path lib.types.package);

        default = { };
        description = "Git hook names mapped to executable script files.";
      };

      config = lib.mkIf (config.gitHooks != { }) {
        packages.install-git-hooks = pkgs.mkGitHooks config.gitHooks;
      };
    }
  );
}
