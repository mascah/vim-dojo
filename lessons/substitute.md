# :s with ranges

`:s/old/new/` replaces the first `old` on the cursor's line with `new`. Add
`g` at the end to replace every match on the line, and put a range in front
to work on more lines: `:2,4s` for lines 2 to 4, `:%s` for the whole file,
`:.,$s` from here to the end.

| Key | What it does |
| --- | --- |
| `:s/{old}/{new}/` | Replace the first match on this line |
| `:s/{old}/{new}/g` | Replace every match on this line |
| `:%s/{old}/{new}/g` | Replace every match in the file |
| `:2,4s/{old}/{new}/` | Replace on lines 2 to 4 only |

## Example

Some hosts in the staging block should change, and the production one
should not:

```text
# staging
url_a = "http://localhost/a"
url_b = "http://localhost/b"
# production
url_c = "http://localhost/c"
```

Type `:2,3s/localhost/staging/` and Enter:

```text
# staging
url_a = "http://staging/a"
url_b = "http://staging/b"
# production
url_c = "http://localhost/c"
```

## When to use it

When the same replacement is needed many times, in a part of the file you
can name by line numbers or from the cursor. Turn on `number` to read the
line numbers off the screen.

## The trap

Forgetting `g`, so only the first match on each line changes and the rest
quietly stay. And `%` on a word that also appears where it should not:
narrow the range, or add `c` to confirm each one.

```json
{
  "id": "substitute",
  "title": ":s",
  "keys": [[":s/{old}/{new}/", "replace on this line"], [":s/{old}/{new}/g", "every match on the line"],
           [":%s/{old}/{new}/g", "every match in the file"], [":2,4s/{old}/{new}/", "on lines 2 to 4"]],
  "scenarios": [
    {"id": "staging-hosts", "ft": "python",
     "vars": {"old": ["localhost", "devbox", "sandbox"], "new": ["staging", "preview", "qahost"]},
     "goal": "Change {old} to {new} on lines 2 to 4 only.",
     "lines": ["# staging", "url_a = \"http://{old}/a\"", "url_b = \"http://{old}/b\"", "url_c = \"http://{old}/c\"",
               "# production", "url_d = \"http://{old}/d\""],
     "solution": ":2,4s/{old}/{new}/<CR>"},
    {"id": "rename-everywhere", "ft": "python",
     "vars": {"old": ["qty", "amt", "cnt"], "new": ["quantity", "amount", "count"]},
     "goal": "Rename every {old} in the file to {new}.",
     "lines": ["def line_total(price, {old}):", "    if {old} <= 0:", "        return 0",
               "    return price * {old} + fee({old})"],
     "solution": ":%s/{old}/{new}/g<CR>"},
    {"id": "to-the-end", "ft": "yaml", "start": "  - name: web",
     "vars": {"old": ["warn", "debug"], "new": ["error", "info"]},
     "goal": "Change level {old} to {new} from the cursor's line to the end of the file.",
     "lines": ["jobs:", "  - name: api", "    level: {old}", "  - name: web", "    level: {old}", "  - name: cron",
               "    level: {old}"],
     "solution": ":.,$s/{old}/{new}/<CR>"},
    {"id": "one-line-all", "ft": "text", "start": "1042",
     "vars": {"sep": [";", "|", ":"]},
     "goal": "On the cursor's line only, change every comma to {sep}.",
     "lines": ["id,name,city,plan", "1042,Ana,Lisbon,pro", "2177,Ravi,Pune,team"],
     "solution": ":s/,/{sep}/g<CR>"}
  ]
}
```
