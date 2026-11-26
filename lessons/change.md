# c

`c` is `d` followed by Insert mode: it deletes over a motion and leaves you
typing where the text was. It takes the same motions as `d`, so everything you
know about deleting carries over. The whole change, deletion and typing, is
one step for `u` and for `.`.

| Key | What it does |
| --- | --- |
| `cw` | Change to the end of the word |
| `ct{c}` | Change up to the next `{c}` |
| `c$` | Change to the end of the line |

## Example

The cursor, shown as `[ ]`, is on the first argument:

```text
resp = client.get([u]rl, timeout=5)
```

Type `ct)`, then `url, timeout=30`, then `Esc`:

```text
resp = client.get(url, timeout=3[0])
```

## When to use it

Whenever you would delete something and then type its replacement. `cw` for
a name, `ct)` for the arguments of a call, `c$` for a value that runs to the
end of the line. Thinking in changes rather than deletes keeps the edit in one
piece, so `.` can repeat it on the next line.

## The trap

Deleting with `d` and then pressing `i` or `a`. It reaches the same text, but
it is a key more and two separate steps, so `.` repeats only the insert. If
you know you will type something, start with `c`.

```json
{
  "id": "change",
  "title": "c",
  "keys": [["cw", "change to the end of the word"], ["ct{c}", "change up to {c}"],
           ["c$", "change to the end of the line"]],
  "snippets": ["go", "python", "typescript", "yaml", "toml"],
  "generators": [
    {
      "at": "(\\zs[^()]\\{3,}\\ze)",
      "cursor": "first",
      "keys": "ct){text}<Esc>",
      "vars": {"text": ["ctx", "req, res", "0, 10", "*args", "path, mode", "None"]},
      "goal": "Replace the highlighted arguments with {text}."
    },
    {
      "at": "^\\s*[A-Za-z_][-A-Za-z0-9_]*\\s*\\%(:=\\|[:=]\\)\\s\\+\\zs[^= ].*",
      "cursor": "first",
      "keys": "c${value}<Esc>",
      "vars": {"value": ["true", "false", "30", "\"primary\"", "[]", "\"eu-west-1\""]},
      "goal": "Change the highlighted value to {value}."
    },
    {
      "at": "\\.\\zs\\a\\w\\{2,}\\ze(",
      "cursor": "first",
      "keys": "cw{name}<Esc>",
      "vars": {"name": ["fetch", "load", "parse", "save", "send"]},
      "goal": "Rename the highlighted method to {name}."
    }
  ]
}
```
