{ lib }:

{
  /**
    Recursively discover flake module files in a directory as a list of paths,
    without importing or evaluating them.

    Gotcha: this delegates to `lib.filesystem.packagesFromDirectoryRecursive`,
    which special-cases `package.nix` — a directory holding it contributes only
    that file and silently ignores its siblings.

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
