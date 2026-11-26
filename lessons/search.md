# / ?

`/` starts a search forward: type the text, press Enter, and the cursor jumps
to the next place it appears, on any line. `?` searches backward. The text is
a pattern, but plain words work as you would expect, and a search wraps round
the end of the file.

| Key | What it does |
| --- | --- |
| `/{text}` | Search forward for `{text}`, then Enter |
| `?{text}` | Search backward for `{text}`, then Enter |

## Example

The cursor, shown as `[ ]`, is at the top of a config file, and you want the
database settings further down:

```text
[t]itle = "Order service"
...
max_connections = 20
```

Type `/max_c`, then Enter:

```text
title = "Order service"
...
[m]ax_connections = 20
```

You rarely need the whole word, only enough of it to be the first match.

## When to use it

When you can see or remember a word near the target and it is more than a
line or two away. A search is often the shortest route anywhere in a file,
and it does not care how many lines or words lie in between.

## The trap

Typing a short search that matches too early, then stepping on with `n`
until you get there. Glance at what lies between: a few more letters, or a
rarer word next to the target, usually hits it first time. Set `incsearch`
to see where the search will land as you type.

```json
{
  "id": "search",
  "title": "/ ?",
  "keys": [["/{text}", "search forward, then Enter"], ["?{text}", "search backward, then Enter"]],
  "moves": true,
  "generators": [
    {"at": "\\<\\a\\w\\{4,}\\>", "keys": "/{0}<CR>", "goal": "Search forward for \"{0}\"."},
    {"at": "\\<\\a\\w\\{4,}\\>", "keys": "?{0}<CR>", "goal": "Search backward for \"{0}\"."}
  ],
  "scenarios": [
    {"id": "find-setting", "ft": "dosini", "start": "[server]", "locate": 1,
     "vars": {"key": ["pool_size", "workers", "timeout"], "port": ["8080", "9000"], "db": ["app", "shop"]},
     "goal": "Put the cursor at the start of the {key} setting.",
     "lines": ["[server]", "host = 0.0.0.0", "port = {port}", "workers = 4", "",
               "[database]", "url = postgres://localhost/{db}", "pool_size = 10", "timeout = 30"],
     "solution": "/{key}<CR>"},
    {"id": "find-helper-back", "ft": "python", "start": "if __name__", "locate": 1,
     "vars": {"fn": ["parse_args", "load_config", "main_loop"]},
     "goal": "Put the cursor at the start of the line that defines {fn}.",
     "lines": ["def parse_args():", "    return sys.argv[1:]", "", "def load_config(path):",
               "    return json.load(open(path))", "", "def main_loop(cfg):", "    while cfg.running:",
               "        cfg.step()", "", "if __name__ == \"__main__\":", "    main_loop(load_config(parse_args()[0]))"],
     "solution": "?def {fn}<CR>"}
  ]
}
```
