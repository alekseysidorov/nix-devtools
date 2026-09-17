{
  lib,
  flake-parts-lib,
  localInputs,
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
      # Built from nix-devtools' own overlay (`inputs` is the provider's set), so the
      # hooks match what downstream users get.
      pkgs = localInputs.nixpkgs.legacyPackages.${system}.extend localInputs.self.overlays.default;
    in
    {
      options.gitHooks = lib.mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.path lib.types.package);

        default = { };
        description = "Git hook names mapped to executable files or packages.";
      };

      config = lib.mkIf (config.gitHooks != { }) {
        packages.install-git-hooks = pkgs.mkGitHooks config.gitHooks;
      };
    }
  );
}
