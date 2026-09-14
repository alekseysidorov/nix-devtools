# lib/default.nix

{ lib }:

{
  /**
    Recursively discover flake module files in a directory.

    Every `.nix` file is returned except files named `default.nix`.
    This allows a directory's `default.nix` to act as the composition root
    while sibling and nested files are discovered automatically.

    The function only discovers module paths; it does not import or evaluate
    the modules.

    # Type

    ```
    flakeModulesFromDirectoryRecursive :: Path -> [ Path ]
    ```
  */
  flakeModulesFromDirectoryRecursive =
    dir:
    lib.collect lib.isPath (
      lib.filesystem.packagesFromDirectoryRecursive {
        directory = dir;
        callPackage = path: _: path;
      }
    );
}
