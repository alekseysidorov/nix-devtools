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

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

        lib = inputs.nixpkgs.lib;

        # Pure Nix utilities exposed independently of package and module APIs.
        nixDevtools = import ./lib {
          inherit lib;
        };

        # Build this repository's package namespace for a given nixpkgs instance.
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

        # Repository-specific checks are intentionally outside the public module.
        repositoryChecks = nixDevtools.flakeModulesFromDirectoryRecursive ./tests;

        # Capture provider-owned dependencies lexically. The same reusable module
        # is consumed by this repository and exported to downstream flakes.
        flakeModule = importApply ./modules {
          inherit inputs localPackagesFor;
        };
      in
      {
        systems = lib.systems.flakeExposed;

        imports = [
          inputs.treefmt-nix.flakeModule
          flakeModule
        ]
        ++ repositoryChecks;

        flake = {
          inherit flakeModule;
          # Keep the project-specific library namespaced under the conventional
          # flake `lib` output so it composes cleanly with other libraries.
          lib.nixDevtools = nixDevtools;
        };

        perSystem =
          {
            system,
            ...
          }:

          let
            # Exercise the same public overlay exposed to downstream consumers.
            pkgs = inputs.nixpkgs.legacyPackages.${system}.extend inputs.self.overlays.default;

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

            # The local namespace also contains builders and helper functions;
            # only concrete derivations are valid flake package outputs.
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
