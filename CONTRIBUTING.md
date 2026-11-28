# Contributing

## Setup

Install Go, at the version `go.mod` names, Vim 9.1.0597 or later, tmux, and
[`just`](https://github.com/casey/just). With
[lefthook](https://lefthook.dev), `lefthook install` formats, vets and tidies
on each commit.

## Commands

```sh
just build     # ./dojo, which reads the lessons next to it
just install   # link ~/.local/bin/dojo to this checkout's build
just test      # the shell's Go tests and the runner's headless Vim suite
just check     # gofmt, vet, both suites, and test/typing.sh; run before every commit
```

`DOJO_SECTION=foundations just test` checks the drill solutions of one
section only. `test/typing.sh` types real keys into Vim through tmux, with
pauses, and plays a round from the shell end to end; it is skipped where tmux
is missing. CI runs `just check` on Linux, with Vim built from source once and cached.

## Commits and pull requests

Every commit on `main` is a squash-merged pull request whose title is a
Conventional Commit (`type(scope): subject`, `!` before the colon for a
breaking change) and whose description is the body, with a
`BREAKING CHANGE:` footer saying what a learner must do. Fixes found in review
go in the same pull request.

- Types: `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`,
  `chore`, `revert`.
- Scopes, when there is one: `shell`, `runner`, `lessons`, `snippets`, `ci`.

## Breaking changes

A change is breaking when a learner has to act to keep what they had: records
or custom drills that no longer load, or a key, command, option or
environment variable renamed or removed. Before 1.0, a breaking change bumps
the minor version.

## Releases

release-please keeps a release pull request open on `main`. The next version
comes from the commit titles since the last release: `fix` bumps the patch
version, `feat` the minor, and a breaking change as above. Merging the release
pull request tags the release, writes `CHANGELOG.md` and creates the GitHub
Release; GoReleaser, in the same workflow, attaches the binaries to it, and
the workflow fails if `install.sh` cannot install one. The lessons and the Vim
runtime are embedded in `dojo`, which writes them to the data directory when
it does not sit next to `lessons/`. `_snippets/` starts with `_` so that the
go tool skips its Go files.

The release pull request is opened with the default token, so CI does not run
on it. Nothing is versioned by hand. For
release-please to open that pull request, the repository's Actions settings
must allow GitHub Actions to create pull requests.
