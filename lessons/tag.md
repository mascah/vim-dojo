# it at

In HTML and XML, `it` is the text between an opening tag and its closing
tag, and `at` is the whole element, tags included. The cursor can be on the
text or on either tag. With nested elements, the object is the innermost one
around the cursor.

| Key | What it does |
| --- | --- |
| `cit` | Change the text inside the tag pair |
| `dit` | Empty the element, keeping its tags |
| `dat` | Delete the whole element |

## Example

The cursor, shown as `[ ]`, is on the text of a button:

```text
<button type="submit" class="primary">Sen[d]</button>
```

Type `cit`, then `Create account`, then `Esc`:

```text
<button type="submit" class="primary">Create accoun[t]</button>
```

## When to use it

On any markup: page text, labels, links, list items. It replaces exactly
the content, however long the attributes on the opening tag, so there is no
picking through angle brackets.

## The trap

Using `ci<` or `ci>`, which change inside a single tag's angle brackets, the
tag name and attributes, rather than the text between tags. `t` is for the
pair. And from inside a nested element, add a count, as in `c2it`, to reach
the outer one.

```json
{
  "id": "tag",
  "title": "it at",
  "keys": [["cit", "change inside the tags"], ["dit", "empty the element"], ["dat", "delete the element"]],
  "snippets": ["html"],
  "generators": [
    {
      "at": ">\\zs[^<>]*\\a[^<>]*\\ze</",
      "keys": "cit{text}<Esc>",
      "vars": {"text": ["Sign in", "Save", "Next", "Learn more", "Orders", "Help"]},
      "goal": "Change the highlighted text to \"{text}\"."
    },
    {
      "at": ">\\zs[^<>]*\\a[^<>]*\\ze</",
      "keys": "dit",
      "goal": "Empty the element, deleting the highlighted text."
    },
    {
      "at": "<\\(\\a\\+\\)[^>]*>[^<>]*</\\1>",
      "keys": "dat",
      "goal": "Delete the highlighted element, tags and all."
    }
  ],
  "scenarios": [
    {"id": "tag-text", "ft": "html", "start": "{old}",
     "vars": {"old": ["Widgets", "Gadgets", "Bolts"], "new": ["Ratchets", "Washers", "Springs"]},
     "lines": ["<ul>", "  <li class=\"item\">{old}</li>", "</ul>"],
     "goal": "Change the list item’s text to {new}.",
     "solution": "cit{new}<Esc>"},
    {"id": "remove-span", "ft": "html", "start": "{x}",
     "vars": {"x": ["raw=42", "id=7", "cache hit"], "label": ["Total:", "Due:", "Count:"]},
     "lines": ["<p>{label}<span class=\"debug\"> {x}</span> due today</p>"],
     "goal": "Remove the debug span and everything in it.",
     "solution": "dat"}
  ]
}
```
