{
  writeScript,
  nushell,
}:

/*
  Run Nu code as a standalone script: no PATH/env setup and no syntax check, and
  the user's Nu config is loaded. Prefer writeNushellApplication beyond trivial
  scripts.
*/
name: text:
writeScript name ''
  #!${nushell}/bin/nu
  ${text}
''
