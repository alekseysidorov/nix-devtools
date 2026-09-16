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
        # Guards sibling resolution in the local namespace (`mkGitHooks` pulls in
        # `writeNushellApplication`).
        test-packages-sibling-dependency = pkgs.mkGitHooks {
          pre-commit = pkgs.writeNushellScript "pre-commit" ''
            print "ok"
          '';
        };
      };
    };
}
