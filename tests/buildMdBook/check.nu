use std/assert

let plain = open --raw ($env.plainBook | path join example.html)
let mermaid = open --raw ($env.mermaidBook | path join example.html)

assert ($plain | str contains 'class="language-mermaid"')
assert ($mermaid | str contains 'class="mermaid"')

# mdBook fingerprints asset names, so follow the generated script references.
let scripts = $mermaid | parse --regex '<script[^>]*src="(?<source>mermaid[^"]+)"' | get source
assert equal ($scripts | length) 2
for script in $scripts {
    let asset = $env.mermaidBook | path join $script
    assert ((open --raw $asset | str length) > 0)
}

assert (open --raw $env.serveScript | str contains $env.mermaidBook)
touch $env.out
