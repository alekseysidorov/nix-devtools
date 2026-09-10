localInputs:

{
  ...
}:

{
  # Only reusable capabilities are part of the public flake module.
  # This repository's test suite is imported separately in flake.nix.
  imports = [
    ./packages.nix
    ./gitHooks.nix
  ];

  _module.args.localInputs = localInputs;
}
