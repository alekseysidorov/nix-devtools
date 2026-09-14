{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";

    crane.url = "github:ipetkov/crane";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };

    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      {
        flake-parts-lib,
        ...
      }:

      let
        inherit (flake-parts-lib) importApply;

        # Build this repository's package set for the given nixpkgs instance.
        localPackagesFor =
          { lib, pkgs }:
          lib.filesystem.packagesFromDirectoryRecursive {
            directory = ./pkgs;

            callPackage = lib.callPackageWith (
              pkgs
              // {
                inherit (inputs)
                  crane
                  rust-advisory-db
                  ;
              }
            );
          };

        # Capture nix-devtools' own inputs once, then reuse the exact same
        # module both internally and as the public flakeModule. The public
        # module must not include this repository's tests, otherwise
        # consumers inherit its checks.
        flakeModule = importApply ./modules { inherit inputs localPackagesFor; };
      in
      {
        systems = inputs.nixpkgs.lib.systems.flakeExposed;

        imports = [
          inputs.treefmt-nix.flakeModule
          flakeModule
          # Repository-specific development policy.
          ./tests
        ];

        flake = { inherit flakeModule; };

        perSystem =
          {
            system,
            ...
          }:
          let
            pkgs = inputs.nixpkgs.legacyPackages.${system}.extend inputs.self.overlays.default;
            lib = inputs.nixpkgs.lib;
            localPackages = localPackagesFor {
              inherit lib pkgs;
            };
          in
          {
            treefmt = {
              projectRootFile = "flake.nix";

              programs = {
                nixfmt.enable = true;
                deno.enable = true;
                rustfmt.enable = true;
              };
            };

            # Only concrete derivations belong in flake packages and automatic checks.
            packages = lib.filterAttrs (_: lib.isDerivation) localPackages;

            gitHooks = {
              pre-commit = pkgs.writeNushellScript "pre-commit" ''
                print "⚡️ Running pre-commit checks..."
                nix fmt -- --fail-on-change
              '';

              pre-push = pkgs.writeNushellScript "pre-push" ''
                print "⚡️ Running pre-push checks..."
                nix flake check -L
              '';
            };
          };
      }
    );
}
