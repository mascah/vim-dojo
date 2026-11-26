# Search as a motion

A search is a motion, so an operator can use it. `d/when` deletes from the
cursor up to the next "when" and keeps the word itself. `c/` and `y/` work
the same way. This reaches across lines too, which `t` and `f` cannot.

| Key | What it does |
| --- | --- |
| `d/{text}` | Delete up to the next `{text}`, then Enter |
| `c/{text}` | Change up to the next `{text}`, then Enter |

## Example

The cursor, shown as `[ ]`, is at the start of a clause to cut:

```text
The job retries [o]nce, and only on weekdays, when the import fails.
```

Type `d/when`, then Enter:

```text
The job retries [w]hen the import fails.
```

## When to use it

When the text to delete ends just before a word you can see, especially when
it runs over more than one line, or when counting words for `d5w` would take
longer than typing the word. It is also the precise way to cut up to a
heading, a label, or a keyword.

## The trap

Searching for a word that also appears earlier than you meant, so the
deletion stops short. Look at the text between the cursor and the target
first, and type enough letters to skip anything that would match before.
If it goes wrong, `u` and try a longer search.

```json
{
  "id": "search-motion",
  "title": "search as a motion",
  "keys": [["d/{text}", "delete up to the next {text}"], ["c/{text}", "change up to the next {text}"]],
  "snippets": ["markdown"],
  "generators": [
    {
      "at": "\\<\\a\\+\\%(\\s\\+\\a\\+\\)\\{2,4}\\s\\+\\(\\a\\{4,}\\)\\>",
      "cursor": "first",
      "keys": "d/{1}<CR>",
      "goal": "Delete from the cursor up to \"{1}\", keeping it."
    }
  ]
}
```
