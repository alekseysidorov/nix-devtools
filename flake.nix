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
    inputs.flake-parts.lib.mkFlake
      {
        inherit inputs;
        # Expose this flake's own inputs to all modules in its module graph.
        specialArgs = {
          localInputs = inputs;
        };
      }
      (
        {
          ...
        }:

        let
          inherit (inputs.nixpkgs) lib;
          # Pure Nix utilities exposed independently of package and module APIs.
          nixDevtools = import ./lib {
            inherit lib;
          };

          # Build this repository's package namespace against a given package set.
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

          localOverlay =
            final: _prev:
            localPackagesFor {
              inherit lib;
              pkgs = final;
            };

          # Repository-specific checks are intentionally outside the public module.
          repositoryChecks = nixDevtools.flakeModulesFromDirectoryRecursive ./tests;
          flakeModule = ./modules;
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
            overlays.default = lib.composeManyExtensions [
              inputs.rust-overlay.overlays.default
              localOverlay
            ];
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
