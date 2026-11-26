# w b e

Word motions cross a line a word at a time. `w` jumps to the start of the
next word, `b` back to the start of this word or the one before, and `e`
forward to the end of a word. To Vim, a word is a run of letters, digits, and
underscores, or a run of punctuation, so `(` and `,` are words of their own.

| Key | What it does |
| --- | --- |
| `w` | Start of the next word |
| `b` | Start of this word, or the one before |
| `e` | End of this word, or the next one |

## Example

The cursor, shown as `[ ]`, is on `return`:

```text
[r]eturn fetchUser(userId, options)
```

Type `w` three times. The second stop is the `(`, because punctuation counts:

```text
return fetchUser([u]serId, options)
```

## When to use it

Whenever the place you want is a few words away on the same line. Count the
words as you look, and press `w` or `b` that many times. Use `e` when you want
to land on a word's last letter, for instance to add something after it.

## The trap

Forgetting that punctuation is a word. In `user.name = value`, getting from
`user` to `name` takes two presses of `w`, one for the `.`. When a line is
dense with symbols, the next section's `W`, which skips them, is often
shorter.

```json
{
  "id": "word",
  "title": "w b e",
  "keys": [["w", "start of the next word"], ["b", "start of this or the previous word"],
           ["e", "end of this or the next word"]],
  "moves": true,
  "generators": [
    {"keys": "{m}", "vars": {"m": ["w", "ww", "www", "e", "ee", "b", "bb", "bbb"]}}
  ]
}
```
