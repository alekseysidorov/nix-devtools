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
        preBuild = ''
          mdbook-mermaid install .
        '';
      };
    in
    {
      checks.test-mdbook-pdf =
        pkgs.runCommand "test-mdbook-pdf"
          {
            nativeBuildInputs = [
              pkgs.nushell
              pkgs.poppler-utils
            ];
            pdfBook = mermaid.pdf;
          }
          ''
            nu --no-config-file ${./buildMdBook/pdf.nu}
          '';

      checks.test-mdbook-preprocessors =
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
