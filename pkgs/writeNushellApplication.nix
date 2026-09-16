{
  lib,
  nushell,
  writeText,
  writeTextFile,
}:

/**
  `writeNushellApplication` is similar to `writeShellApplication`, but `text` is
  Nushell code and the script runs without a Bash wrapper. It writes an executable
  script to `/nix/store/<store path>/bin/<name>` and checks its syntax with
  `nu-check` without executing it; the shebang passes `--no-config-file`, so the
  user's Nu configuration cannot affect the script.

  # Arguments

  `name` (String)
  : The name of the script to write.

  `text` (String)
  : The Nushell code to run, not including a shebang.

  `runtimeInputs` (List of derivations or strings, _optional_)
  : Inputs to add to the script's `$PATH` at runtime. Each element is either a
    derivation, or a string containing a path, which is suffixed with `/bin`.

  `runtimeEnv` (Attribute set, _optional_)
  : Extra environment variables to set at runtime. Values are stringified and
    loaded from JSON, so they land in the Nix store — do not put secrets here.
    Note `toString` renders booleans as `"1"`/`""`.

  `inheritPath` (Bool, _optional_)
  : Whether the script inherits `$PATH` from its parent environment. _Default:_ `true`.

  `extraConfig` (String, _optional_)
  : Nushell code to run after the environment and `$PATH` are set up, before `text`.

  `checkPhase` (String, _optional_)
  : The `checkPhase` to run; the script path is given as `$target`. _Default:_ check
    syntax with `nu-check` without executing commands.

  `meta`, `passthru` (Attribute sets, _optional_)
  : `writeTextFile`'s `meta` and `passthru` arguments; `meta` is merged over the
    generated `mainProgram`.

  `derivationArgs` (Attribute set, _optional_)
  : Extra `writeTextFile` arguments, applied when the script is _built_ rather than
    run. Certain derivation attributes are set internally, so overriding those
    could cause problems.

  # Example

  ```nix
  writeNushellApplication {
    name = "hello";
    runtimeInputs = [ git ];
    runtimeEnv.MESSAGE = "hello";
    text = ''
      print $env.MESSAGE
      git --version
    '';
  }
  ```
*/
{
  name,
  text,
  runtimeInputs ? [ ],
  runtimeEnv ? null,
  inheritPath ? true,
  extraConfig ? "",
  meta ? { },
  passthru ? { },
  checkPhase ? null,
  derivationArgs ? { },
}:
let
  nu = lib.getExe nushell;
  runtimePath = builtins.toJSON (map (pkg: "${lib.getBin pkg}/bin") runtimeInputs);
  inheritedPath = lib.optionalString inheritPath " ++ ($env.PATH? | default [])";

  # Keep environment values as data, not executable Nu code.
  environment = writeText "${name}-env.json" (
    builtins.toJSON (lib.mapAttrs (_: value: toString value) runtimeEnv)
  );
  loadEnvironment = lib.optionalString (runtimeEnv != null) "load-env (open ${environment})";

  syntaxCheck = ''
    target="$target" ${nu} --no-config-file -c 'nu-check --debug $env.target | if not $in { exit 1 }'
  '';
in
writeTextFile {
  inherit name passthru derivationArgs;
  meta = {
    mainProgram = name;
  }
  // meta;
  executable = true;
  destination = "/bin/${name}";
  text = ''
    #!${nu} --no-config-file
    ${loadEnvironment}
    $env.PATH = ${runtimePath}${inheritedPath}
    ${extraConfig}
    ${text}
  '';
  checkPhase = if checkPhase == null then syntaxCheck else checkPhase;
}
