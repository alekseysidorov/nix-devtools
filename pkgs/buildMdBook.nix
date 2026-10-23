{
  lib,
  mdbook,
  mdbook-pdf,
  playwright-driver,
  python3,
  shell-status,
  stdenvNoCC,
  writeShellApplication,
}:

{
  pname,
  src,
  version ? "current",
  nativeBuildInputs ? [ ],
  preBuild ? "",
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname version preBuild;

  src = lib.cleanSource src;
  nativeBuildInputs = [ mdbook ] ++ nativeBuildInputs;

  buildPhase = ''
    runHook preBuild
    mdbook build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp -r target/book "$out"
    runHook postInstall
  '';

  passthru.pdf = finalAttrs.finalPackage.overrideAttrs (old: {
    pname = "${pname}-pdf";
    nativeBuildInputs = old.nativeBuildInputs ++ [ mdbook-pdf ];
    preBuild = old.preBuild + ''
      export HOME="$TMPDIR"
      export MDBOOK_OUTPUT__PDF__COMMAND="${mdbook-pdf}/bin/mdbook-pdf"
      export MDBOOK_OUTPUT__PDF__BROWSER_BINARY_PATH="$(find ${playwright-driver.components.chromium-headless-shell} -type f -name chrome-headless-shell)"
      test -x "$MDBOOK_OUTPUT__PDF__BROWSER_BINARY_PATH"
      export MDBOOK_OUTPUT__HTML__PRINT__ENABLE=true
    '';
    installPhase = ''
      runHook preInstall
      cp target/book/pdf/output.pdf "$out"
      runHook postInstall
    '';
    passthru = { };
  });

  passthru.serve = writeShellApplication {
    name = "${pname}-serve";
    runtimeInputs = [
      python3
      shell-status
    ];
    text = ''
      port="''${MD_BOOK_SERVE_PORT:-3000}"
      shell-status info mdbook "Serving mdbook on: http://localhost:$port"
      shell-status info mdbook "To stop server type ctrl+c"
      python3 -m http.server "$port" --directory "${finalAttrs.finalPackage}"
    '';
  };
})
