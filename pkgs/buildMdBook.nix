{
  lib,
  mdbook,
  python3,
  shell-status,
  stdenvNoCC,
  writeShellApplication,
}:

{
  pname,
  src,
  version ? "current",
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname version;

  src = lib.cleanSource src;
  nativeBuildInputs = [ mdbook ];

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
