{
  inputs,
  ...
}:

{
  perSystem =
    { system, ... }:

    let
      pkgs = inputs.nixpkgs.legacyPackages.${system}.extend inputs.self.overlays.default;
    in
    {
      checks = {
        test-packages-sibling-dependency = pkgs.mkGitHooks {
          pre-commit = pkgs.writeNushellScript "pre-commit" ''
            print "ok"
          '';
        };
      };
    };
}
