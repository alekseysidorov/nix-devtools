use std/assert

let info = ^pdfinfo $env.pdfBook
assert ($info | str contains "Pages:")
assert ($info | str contains "Encrypted:       no")
touch $env.out
