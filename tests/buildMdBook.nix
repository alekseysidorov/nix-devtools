{ inputs, ... }:

{
  perSystem =
    { system, ... }:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system}.extend inputs.self.overlays.default;

      plain = pkgs.buildMdBook {
        pname = "mdbook-plain-test";
        src = ./buildMdBook/fixtures;
      };

      mermaid = pkgs.buildMdBook {
        pname = "mdbook-mermaid-test";
        src = ./buildMdBook/fixtures;
        nativeBuildInputs = [ pkgs.mdbook-mermaid ];
        passthru.reference = plain;
        preBuild = ''
          mdbook-mermaid install .
        '';
      };
    in
    {
      checks.test-mdbook-preprocessors =
        assert mermaid.reference == plain;
        pkgs.runCommand "test-mdbook-preprocessors"
          {
            nativeBuildInputs = [ pkgs.nushell ];
            plainBook = plain;
            mermaidBook = mermaid;
            serveScript = "${mermaid.serve}/bin/mdbook-mermaid-test-serve";
          }
          ''
            nu --no-config-file ${./buildMdBook/check.nu}
          '';
    };
}
