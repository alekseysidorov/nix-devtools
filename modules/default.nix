moduleArgs:

{
  flake-parts-lib,
  ...
}:

let
  inherit (flake-parts-lib) importApply;
in
{
  imports = map (path: importApply path moduleArgs) [
    ./packages.nix
    ./gitHooks.nix
  ];
}
