inputs:

{
  flake-parts-lib,
  ...
}:

let
  inherit (flake-parts-lib) importApply;
in
{
  imports = map (path: importApply path inputs) [
    ./gitHooks.nix
  ];
}
