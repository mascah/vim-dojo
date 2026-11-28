# shelf

A small command-line tool for keeping track of the books you own, the ones
you have lent out, and who has them.

## Install

    go install example.test/shelf@latest

You need Go 1.22 or later. The binary has no other dependencies.

## Usage

Add a book by its ISBN, and shelf looks up the title and author for you:

    shelf add 9780141439518
    shelf lend 9780141439518 --to "Noor"
    shelf list --lent

Books are stored in `~/.local/share/shelf/books.json`. The file is plain
JSON, so you can back it up (or edit it by hand) without the tool.

## Configuration

| Setting    | Default       | Meaning                              |
| ---------- | ------------- | ------------------------------------ |
| `lookup`   | `openlibrary` | Where titles and authors come from   |
| `reminder` | `30d`         | When to remind you about a lent book |
| `color`    | `auto`        | Whether to colour the output         |

## Contributing

Bug reports and small pull requests are welcome. Please run `go test ./...`
before you send one, and describe the problem the change solves.
