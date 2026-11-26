# iw aw

`iw` is the word under the cursor, from its first letter to its last, and
`aw` is the word with one space beside it. With them the cursor can be
anywhere on the word: `ciw` replaces it, `daw` removes it from a sentence,
`yiw` copies it.

| Key | What it does |
| --- | --- |
| `ciw` | Change the word under the cursor |
| `daw` | Delete the word and one space |
| `yiw` | Copy the word under the cursor |

## Example

The cursor, shown as `[ ]`, is in the middle of a name:

```text
subto[t]al = price * qty
```

Type `ciw`, then `net`, then `Esc`:

```text
ne[t] = price * qty
```

## When to use it

Whenever the word is the unit: renaming a variable, swapping one word for
another, dropping a word from a sentence. It saves getting to the word's
first letter, which `cw` and `dw` would need.

## The trap

Using `cw` from the middle of a word. It changes only from the cursor to the
end, leaving the first half behind. `ciw` takes the whole word wherever you
are on it. And remember what a word is: `user_id` is one word, but
`user.id` is three.

```json
{
  "id": "word-object",
  "title": "iw aw",
  "keys": [["ciw", "change the word"], ["daw", "delete the word and a space"], ["yiw", "copy the word"]],
  "snippets": ["go", "python", "typescript"],
  "generators": [
    {
      "at": "\\<\\a\\w\\{3,}\\>",
      "keys": "ciw{text}<Esc>",
      "vars": {"text": ["count", "total", "result", "limit", "items", "owner"]},
      "goal": "Change the highlighted word to {text}."
    },
    {
      "at": "\\<\\a\\{4,} \\ze\\a",
      "keys": "daw",
      "goal": "Delete the highlighted word and its space."
    }
  ],
  "scenarios": [
    {"id": "rename-variable", "ft": "python", "start": "{at}",
     "vars": {"var": [{"old": "subtotal", "at": "total"}, {"old": "amount", "at": "ount"},
                      {"old": "item_count", "at": "count"}],
              "new": ["net_total", "line_cost", "quantity"]},
     "lines": ["{old} = price * qty", "print({old})"],
     "goal": "On the first line, rename {old} to {new}.",
     "solution": "ciw{new}<Esc>"},
    {"id": "copy-name", "ft": "go", "start": "{at}",
     "vars": {"pick": [{"name": "maxRetries", "at": "Retries"}, {"name": "baseDelay", "at": "Delay"},
                       {"name": "pollEvery", "at": "Every"}]},
     "lines": ["const {name} = 5", "", "func run() {", "    log.Println()", "}"],
     "goal": "Copy the name {name} and put it inside the empty Println() call.",
     "solution": "yiw/(<CR>p"}
  ]
}
```
