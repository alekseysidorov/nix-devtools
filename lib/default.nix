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
    lib.filter (path: lib.hasSuffix ".nix" (toString path) && lib.baseNameOf path != "default.nix") (
      lib.filesystem.listFilesRecursive dir
    );
}
