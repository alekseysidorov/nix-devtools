{
  lib,
  nushell,
  writeText,
  writeTextFile,
}:

/**
  `writeNushellApplication` is similar to `writeShellApplication`, but `text` is
  Nushell code and the script runs without a Bash wrapper.

  Writes an executable Nushell script to `/nix/store/<store path>/bin/<name>` and
  checks its syntax with `nu-check` without executing it. The shebang runs Nu with
  `--no-config-file`, so the user's Nu configuration cannot affect the script.

  Variables set through `derivationArgs` are set when the script is _built_, not
  when it is run.

  `writeNushellApplication` has the following arguments:

  `name` (String)
  : The name of the script to write.

  `text` (String)
  : The Nushell code to run, not including a shebang.

  `runtimeInputs` (List of derivations or strings, _optional_)
  : Inputs to add to the script's `$PATH` at runtime.

    Each element can either be a normal derivation, or a string containing a path,
    in which case it is suffixed with `/bin`.

  `runtimeEnv` (Attribute set, _optional_)
  : Extra environment variables to set at runtime.

    Values are stringified and loaded from JSON, so they are written to the Nix
    store — do not put secrets here. Note that `toString` renders booleans as
    `"1"`/`""`.

  `inheritPath` (Bool, _optional_)
  : Whether the script inherits the `$PATH` from its parent environment.

    _Default:_ `true`

  `extraConfig` (String, _optional_)
  : Nushell code to run after the environment and `$PATH` are set up, and before
    `text`.

  `checkPhase` (String, _optional_)
  : The `checkPhase` to run.

    The script path is given as `$target` in the `checkPhase`.

    _Default behaviour:_ check syntax with `nu-check` (check syntax but don't
    execute commands).

  `meta` (Attribute set, _optional_)
  : `writeTextFile`'s `meta` argument, merged over the generated `mainProgram`.

  `passthru` (Attribute set, _optional_)
  : `writeTextFile`'s `passthru` argument.

  `derivationArgs` (Attribute set, _optional_)
  : Extra arguments to pass to `writeTextFile`. Note that certain derivation
    attributes are also set internally, so overriding those could cause problems.

  # Example

  ```nix
  writeNushellApplication {
    name = "hello";

    runtimeInputs = [
      git
    ];

    runtimeEnv = {
      MESSAGE = "hello";
    };

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
