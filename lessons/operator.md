# Verb + motion

Most Vim edits are a sentence of two parts: a verb, then where it applies.
The verbs are operators: `d` deletes, `c` changes, which deletes and goes
into Insert mode, and `y` yanks, which copies. Where is any motion you know,
so `dw` deletes to the next word and `c$` changes to the end of the line.
Every verb can use every motion.

| Key | What it does |
| --- | --- |
| `d{motion}` | Delete from the cursor to where the motion goes |
| `c{motion}` | Delete the same way, then insert |
| `y{motion}` | Copy the same text without changing it |

## Example

The cursor, shown as `[ ]`, is at the start of `unused`:

```text
total = [u]nused base_price * qty
```

Type `dw`:

```text
total = [b]ase_price * qty
```

`dw` took the word and the space after it. `de` would have kept the space,
and `cw` would have left you typing in its place.

## When to use it

Any time you are about to delete or retype more than a character or two.
Say the edit as a sentence, "delete to the end of the word", and type it.

## The trap

Deleting by pressing `x` again and again. It works, but each press is a
change of its own, so `u` takes back one letter and `.` repeats one letter.
Note also that `cw` changes to the end of the word, like `ce`, not up to the
next word as `dw` does.

```json
{
  "id": "operator",
  "title": "verb + motion",
  "keys": [["d{motion}", "delete over a motion"], ["c{motion}", "change over a motion"],
           ["y{motion}", "yank over a motion"]],
  "snippets": ["go", "python", "typescript"],
  "generators": [
    {
      "at": "\\<\\w\\{4,} \\ze\\w",
      "cursor": "first",
      "keys": "dw",
      "goal": "Delete the highlighted word and the space after it."
    },
    {
      "at": "\\<\\w\\{5,}\\ze[,.;)]",
      "cursor": "first",
      "keys": "de",
      "goal": "Delete the highlighted word, keeping the punctuation after it."
    },
    {
      "at": "\\<\\a\\w\\{3,}\\>",
      "cursor": "first",
      "keys": "cw{text}<Esc>",
      "vars": {"text": ["count", "total", "result", "limit", "items", "owner"]},
      "goal": "Change the highlighted word to {text}."
    }
  ]
}
```
