# dd cc D C

Doubling an operator makes it act on the whole line, wherever the cursor is
on it: `dd` deletes the line, `cc` replaces it. The capitals act from the
cursor to the end of the line: `D` is `d$` and `C` is `c$`. `J`, which joins
the next line onto this one, belongs here too.

| Key | What it does |
| --- | --- |
| `dd` | Delete the whole line |
| `cc` | Replace the whole line, keeping its indent if Vim indents |
| `D` | Delete from the cursor to the end of the line |
| `C` | Change from the cursor to the end of the line |
| `J` | Join the next line onto this one, with one space |

## Example

The cursor, shown as `[ ]`, is somewhere on a debugging line:

```text
def load(path):
    print("loa[d]ing", path)
    return read(path)
```

Type `dd`:

```text
def load(path):
    [r]eturn read(path)
```

## When to use it

When the line is the unit: a stray `print`, a line to rewrite, a comment
to drop off the end. `dd` and `cc` save you finding the start of the line;
`D` and `C` save typing `$`. Use `J` when a statement was broken over two
lines and should be one.

## The trap

Going to the start with `0` before `d$`. `dd` already takes the whole line,
and `cc` keeps the indent where `0c$` would not.

```json
{
  "id": "line-ops",
  "title": "dd cc D C",
  "keys": [["dd", "delete the line"], ["cc", "replace the line"], ["D", "delete to the end of the line"],
           ["C", "change to the end of the line"], ["J", "join the next line"]],
  "snippets": ["python", "yaml", "toml"],
  "generators": [
    {"at": "^.*\\S.*$", "keys": "dd", "goal": "Delete the highlighted line."},
    {
      "at": "^\\s*\\zs\\S.*",
      "keys": "cc# TODO: rewrite<Esc>",
      "goal": "Replace the highlighted line with \"# TODO: rewrite\"."
    },
    {"at": "\\S\\s\\+\\zs#.*", "cursor": "first", "keys": "D", "goal": "Delete the highlighted comment."},
    {
      "at": "^\\s*[-A-Za-z_][-A-Za-z0-9_]*\\s*[:=]\\s\\+\\zs[^= ].*",
      "cursor": "first",
      "keys": "C{value}<Esc>",
      "vars": {"value": ["true", "false", "30", "\"primary\"", "[]"]},
      "goal": "Change the highlighted value to {value}."
    }
  ],
  "scenarios": [
    {"id": "join-call", "ft": "python", "start": "{fn}",
     "vars": {"fn": ["fetch", "upload", "delete"], "arg": ["timeout=5", "retries=2", "force=True"]},
     "lines": ["def run(url):", "    result = {fn}(url,", "        {arg})", "    return result"],
     "goal": "Join the {fn}() call back onto one line.",
     "solution": "J"},
    {"id": "join-sentence", "ft": "markdown", "start": "{a}",
     "vars": {"a": ["The import", "The nightly job", "The cache"], "b": ["runs at two.", "retries once.", "is cleared on deploy."]},
     "lines": ["# Notes", "", "{a}", "{b}", "", "Ask in the team channel."],
     "goal": "Join the two halves of the sentence into one line.",
     "solution": "J"},
    {"id": "join-list", "ft": "typescript", "start": "const",
     "vars": {"name": ["roles", "tags", "regions"], "a": ["\"admin\"", "\"beta\"", "\"eu\""], "b": ["\"viewer\"", "\"stable\"", "\"us\""]},
     "lines": ["const {name} = [", "  {a}, {b}", "];"],
     "goal": "Join all three lines into one, so the list reads on one line.",
     "solution": "JJ"}
  ]
}
```
