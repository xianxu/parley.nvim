-- One representation matrix shared by admission and real tool-effect tests.
return {
    { name = 'indented root', header = { '  collaboration-mode: chat' } },
    { name = 'indented root siblings', header = { '  title: sample', '  collaboration-mode: chat' } },
    { name = 'quoted root key', header = { "'collaboration-mode': chat" } },
    { name = 'escaped root key', header = { '"collaboration\\u002dmode": chat' } },
    { name = 'root flow', header = { '{collaboration-mode: chat}' } },
    { name = 'multiline root flow', header = { '{', '  collaboration-mode: chat', '}' } },
    { name = 'root sequence', header = { '- collaboration-mode: chat' } },
    { name = 'explicit key', header = { '? collaboration-mode', ': chat' } },
    { name = 'root tag', header = { '!!map', 'collaboration-mode: chat' } },
    { name = 'root anchor', header = { '&root', 'collaboration-mode: chat' } },
    { name = 'root alias', header = { '*routing' } },
    { name = 'root merge', header = { 'defaults: &defaults', '  collaboration-mode: chat', '<<: *defaults' } },
    { name = 'unclosed frontmatter', header = { 'title: sample' }, closed = false },
    { name = 'unclosed escaped key', header = { '"collaboration\\u002dmode": chat' }, closed = false },
    { name = 'unclosed root flow', header = { '{collaboration-mode: chat}' }, closed = false },
}
