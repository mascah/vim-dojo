# W B E

The capital word motions treat anything between spaces as one word, which Vim
calls a WORD. `user.profile.name()` is six words to `w`, because every `.` and
bracket is a word of its own, but one WORD to `W`. Otherwise they move like
their lowercase partners.

| Key | What it does |
| --- | --- |
| `W` | Start of the next WORD |
| `B` | Start of this WORD, or the one before |
| `E` | End of this WORD, or the next one |

## Example

The cursor, shown as `[ ]`, is at the start of the line:

```text
[r]eturn user.profile.name() || fallback
```

Type `W` twice. Each press skips to the next space, past all the dots and
brackets:

```text
return user.profile.name() [|]| fallback
```

With `w`, the same stop takes seven presses.

## When to use it

On code and paths, where punctuation splits what you think of as one word
into many: calls, URLs, file names, dotted keys. Look at the spaces, not the
words, and count those.

## The trap

Using `W` everywhere. Inside a long WORD it jumps right over the part you
wanted, such as the `profile` in `user.profile.name()`. When the target is inside
a run of punctuation, `w`, or a find from the next lesson, gets you there.

```json
{
  "id": "big-word",
  "title": "W B E",
  "keys": [["W", "start of the next WORD"], ["B", "start of this or the previous WORD"],
           ["E", "end of this or the next WORD"]],
  "moves": true,
  "snippets": ["go", "python", "typescript", "html"],
  "generators": [
    {"keys": "{m}", "vars": {"m": ["W", "WW", "WWW", "E", "EE", "B", "BB", "BBB"]}}
  ]
}
```
