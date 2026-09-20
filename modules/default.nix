localInputs:

{ flake-parts-lib, ... }:

{
  imports = [
    (flake-parts-lib.importApply ./gitHooks.nix localInputs)
  ];
}
