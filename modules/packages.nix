{ inputs, localPackagesFor }:

{
  lib,
  ...
}:

let
  localOverlay =
    final: _prev:
    localPackagesFor {
      inherit lib;
      pkgs = final;
    };

  packageOverlay = lib.composeManyExtensions [
    inputs.rust-overlay.overlays.default
    localOverlay
  ];
in
{
  flake.overlays.default = packageOverlay;
}
