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
        preprocessors = [ pkgs.mdbook-mermaid ];
        preBuild = ''
          mdbook-mermaid install .
        '';
      };
    in
    {
      checks.test-mdbook-preprocessors =
        pkgs.runCommand "test-mdbook-preprocessors" { nativeBuildInputs = [ pkgs.python3 ]; }
          ''
            grep -F 'class="language-mermaid"' ${plain}/example.html
            grep -F 'class="mermaid"' ${mermaid}/example.html
            python3 - <<'PYTHON'
            from html.parser import HTMLParser
            from pathlib import Path

            class Scripts(HTMLParser):
                sources = []

                def handle_starttag(self, tag, attributes):
                    if tag == "script":
                        self.sources.append(dict(attributes).get("src", ""))

            book = Path("${mermaid}")
            parser = Scripts()
            parser.feed((book / "example.html").read_text())
            scripts = [source for source in parser.sources if source.startswith("mermaid")]
            assert len(scripts) == 2, scripts
            for source in scripts:
                assert (book / source).stat().st_size > 0, source
            PYTHON
            grep -F '${mermaid}' ${mermaid.serve}/bin/mdbook-mermaid-test-serve
            touch $out
          '';
    };
}
