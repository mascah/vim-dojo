# v

`v` starts a selection at the cursor. Any motion then grows it: `e`, `f`,
`t`, a search, even `j` across lines. When it covers the right text, an
operator acts on it: `d` deletes, `c` changes, `y` copies, `U` makes it
uppercase. `Esc` drops the selection.

| Key | What it does |
| --- | --- |
| `v` | Start selecting characters at the cursor |
| `d` `c` `y` | Delete, change or copy the selection |
| `U` | Make the selection uppercase |

## Example

The cursor, shown as `[ ]`, is at the start of two words in a title:

```text
TITLE = "The [q]uick easy guide to Vim"
```

Type `vee` to select both words, then `c`, `practical` and `Esc`:

```text
TITLE = "The practica[l] guide to Vim"
```

## When to use it

When the text is not one neat word or object, and you would like to see
exactly what you are about to change. Visual mode shows the reach of each
motion before you commit to it, which helps with searches and with
selections that cross lines.

## The trap

Selecting first out of habit when an operator and a motion would do it in
fewer keys: `vt,d` is just `dt,` the long way. Visual mode earns its keys
when you are unsure where a motion ends, or when you need to adjust the
selection a few times before acting.

```json
{
  "id": "charwise",
  "title": "v",
  "keys": [["v", "select characters"], ["d", "delete the selection"], ["c", "change it"], ["U", "uppercase it"]],
  "scenarios": [
    {"id": "retitle", "ft": "python", "start": "{a1}",
     "vars": {"adj": [{"a1": "quick", "a2": "easy"}, {"a1": "complete", "a2": "illustrated"}, {"a1": "short", "a2": "friendly"}],
              "new": ["practical", "definitive", "modern"], "topic": ["Vim", "regular expressions", "shell scripts"]},
     "goal": "Change \"{a1} {a2}\" in the title to \"{new}\".",
     "lines": ["TITLE = \"The {a1} {a2} guide to {topic}\""],
     "solution": "veec{new}<Esc>"},
    {"id": "cut-clause", "ft": "text", "start": ", {step}",
     "vars": {"day": ["Monday", "Friday"], "step": ["after the review", "once the build is green", "before the freeze"]},
     "goal": "Delete \", {step}\" so the sentence reads \"Ship it on {day}, if the tests pass.\"",
     "lines": ["Ship it on {day}, {step}, if the tests pass."],
     "solution": "vt,d"},
    {"id": "change-to-word", "ft": "text", "start": "when",
     "vars": {"src": ["upstream", "partner", "billing"]},
     "goal": "Change \"when the {src} feed fails\" to \"on error\".",
     "lines": ["Retry the import when the {src} feed fails, then page the on-call."],
     "solution": "v/fails<CR>econ error<Esc>"},
    {"id": "upper-level", "ft": "python", "start": "{lvl}\"",
     "vars": {"lvl": ["warn", "info", "debug"]},
     "goal": "Make \"{lvl}\" uppercase.",
     "lines": ["import logging", "", "LOG_LEVEL = \"{lvl}\"", "logging.basicConfig(level=LOG_LEVEL)"],
     "solution": "veU"}
  ]
}
```
