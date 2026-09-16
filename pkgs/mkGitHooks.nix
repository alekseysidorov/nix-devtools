{
  lib,
  buildPackages,
  writeNushellApplication,
}:

/**
  Build an `install-git-hooks` executable from a set of hooks.

  Running the result inside a repository copies each hook into the directory
  reported by `git rev-parse --git-path hooks` and marks it executable. Hooks are
  taken as ready-made executable artifacts, not as inline script bodies.

  # Arguments

  `hooks` (Attribute set of paths or derivations)
  : Hook names mapped to executable files or packages.

  # Example

  ```nix
  mkGitHooks {
    pre-commit = writeNushellScript "pre-commit" ''
      nix fmt -- --fail-on-change
    '';
  }
  ```
*/
hooks:

let
  installHook = name: script: ''
    cp ${script} ($hooksDir | path join ${builtins.toJSON name})
    chmod +x ($hooksDir | path join ${builtins.toJSON name})
    print ${builtins.toJSON "⚡️ Installed ${name} hook"}
  '';

  installHooks = lib.pipe hooks [
    (lib.mapAttrsToList installHook)
    (lib.concatStringsSep "\n")
  ];
in
writeNushellApplication {
  name = "install-git-hooks";

  # Runs on the invoking machine, so the tools come from `buildPackages`.
  runtimeInputs = [
    buildPackages.git
    buildPackages.coreutils
  ];

  text = ''
    let hooksDir = (git rev-parse --git-path hooks)
    mkdir $hooksDir

    ${installHooks}
  '';
}
