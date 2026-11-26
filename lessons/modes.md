# Modes and Esc

Vim starts in Normal mode, where every key is a command: `w` moves, `x`
deletes, `u` undoes. To type text you go into Insert mode, where keys type as
they do in any editor, and when you are done you come back with `Esc`. Most of
your time is spent in Normal mode. Insert mode is a short visit.

| Key | What it does |
| --- | --- |
| `i` | Go into Insert mode before the cursor |
| `Esc` | Come back to Normal mode |
| `Ctrl-[` | The same as `Esc`, without leaving the home row |

## Example

The cursor, shown as `[ ]`, is on the first letter of `safe`:

```text
Retries are [s]afe for reads.
```

Type `i`, then `only `, then `Esc`:

```text
Retries are only[ ]safe for reads.
```

Back in Normal mode, the cursor sits on the last character you typed.

## When to use it

Leave Insert mode as soon as the text is typed. Moving, deleting, and
repeating are Normal mode commands, one key away once you are out. The dojo
checks a goal when you are back in Normal mode, so every edit here ends with
`Esc`.

## The trap

Staying in Insert mode and moving with the arrow keys. Each press moves one
character, and it splits your edit in two, so `u` undoes only half of it and
`.` repeats only the end. Press `Esc`, move with a Normal mode command, and go
back in.

```json
{
  "id": "modes",
  "title": "modes and Esc",
  "keys": [["i", "go into Insert mode before the cursor"], ["Esc", "come back to Normal mode"]],
  "snippets": ["markdown"],
  "generators": [
    {
      "at": "\\<\\a\\{4,}\\>",
      "cursor": "first",
      "keys": "i{word} <Esc>",
      "vars": {"word": ["only", "still", "always", "rarely", "also", "never", "often", "now"]},
      "goal": "Put the word \"{word}\" and a space in front of the highlighted word."
    }
  ]
}
```
