{
  nix-gitignore,
}:

/*
  Filter the project through its root `.gitignore`, then optionally select a
  subdirectory of the filtered result.

  `projectRoot` is the project directory holding the `.gitignore` to apply;
  `sourceDir` is a path relative to it (default `.`) that must exist in the output.

  Only the root `.gitignore` is honoured; nested `.gitignore` files are ignored.

  Example: projectSource { projectRoot = ./.; sourceDir = "crates"; }
*/
{
  projectRoot,
  sourceDir ? ".",
}:
let
  source = nix-gitignore.gitignoreSource [ ] projectRoot;
in
if sourceDir == "." then source else "${source}/${sourceDir}"
