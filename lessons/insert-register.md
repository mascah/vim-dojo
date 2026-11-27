# Ctrl-R in Insert

In Insert mode, `Ctrl-R` followed by a register name types out that
register's text, as if you had typed it yourself. `Ctrl-R 0` gives your last
yank and `Ctrl-R a` register `a`. You stay in Insert mode and carry on
typing, so a long name can land in the middle of new text.

| Key | What it does |
| --- | --- |
| `Ctrl-R 0` | Type the last yank |
| `Ctrl-R {a}` | Type register `{a}` |

## Example

The cursor, shown as `[ ]`, is on a function's name, and you want to log it
in the body:

```text
def [l]oad_inventory():
    pass
```

Type `yiw`, then `jo`, then `log("`, `Ctrl-R 0`, `")`, and `Esc`:

```text
def load_inventory():
    pass
    log("load_inventory"[)]
```

## When to use it

When new text should contain something already in the file: a function
name in a log message, a base URL in a second URL, a name in a doc
comment. Yank it once, then type around it, with no leaving Insert mode to
put it and coming back.

## The trap

Leaving Insert mode, pressing `p`, and then `a` to carry on. It works, but
`p` puts after the cursor, which is often one character off, and the edit
breaks into pieces that `.` cannot repeat as one. `Ctrl-R` keeps it one
change.

```json
{
  "id": "insert-register",
  "title": "Ctrl-R",
  "keys": [["Ctrl-R 0", "type the last yank"], ["Ctrl-R {a}", "type register {a}"]],
  "scenarios": [
    {"id": "log-function", "ft": "python",
     "vars": {"name": ["load_inventory", "refresh_tokens", "export_report", "rebuild_search_index"]},
     "goal": "Below pass, add the line log(\"{name}\").",
     "lines": ["def {name}():", "    pass"],
     "solution": "wyiwjolog(\"<C-R>0\")<Esc>"},
    {"id": "health-url", "ft": "python",
     "vars": {"host": ["api.example.test", "shop.example.test", "staging.example.test"]},
     "goal": "Below BASE, add the line HEALTH = \"https://{host}/health\".",
     "lines": ["BASE = \"https://{host}\""],
     "solution": "yi\"oHEALTH = \"<C-R>0/health\"<Esc>"},
    {"id": "error-message", "ft": "python",
     "vars": {"name": ["load_config", "read_rows", "open_cache"]},
     "goal": "Make the error read ValueError(\"{name} needs a path\").",
     "lines": ["def {name}(path):", "    if not path:", "        raise ValueError()"],
     "solution": "wyiwGf(a\"<C-R>0 needs a path\"<Esc>"},
    {"id": "doc-comment", "ft": "go",
     "vars": {"name": ["deleteOrder", "purgeUser", "dropCache"]},
     "goal": "Above the function, add the comment // {name} is called by the scheduler.",
     "lines": ["func {name}(id int) error {", "    return nil", "}"],
     "solution": "wyiwO// <C-R>0 is called by the scheduler.<Esc>"}
  ]
}
```
