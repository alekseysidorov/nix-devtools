{
  writeScript,
  nushell,
}:

/*
  Run Nu code as a standalone script: a Nu shebang plus `text`, written to the store
  path root rather than `/bin`. Unlike writeNushellApplication it adds no
  `$PATH`/environment setup and no syntax check.
*/
name: text:
writeScript name ''
  #!${nushell}/bin/nu
  ${text}
''
