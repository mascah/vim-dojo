default:
    @just --list

# Build ./dojo, which reads the lessons next to it.
build:
    go build -o dojo .

# Link ~/.local/bin/dojo to this checkout's build, as the everyday dojo.
install: build
    mkdir -p ~/.local/bin
    ln -sf "{{justfile_directory()}}/dojo" ~/.local/bin/dojo

# The shell's Go tests and the runner's headless suite; DOJO_SECTION=foundations checks one section.
test:
    go test ./...
    vim -Nu NONE -i NONE -n -es -S test/dojo.vim

# gofmt, vet, both suites, and real keys typed through tmux. snippets/ is drill text, left unformatted.
check:
    @test -z "$(gofmt -l *.go)" || { gofmt -l *.go; echo "gofmt: files need formatting"; exit 1; }
    go vet ./...
    go test ./...
    vim -Nu NONE -i NONE -n -es -S test/dojo.vim
    sh test/typing.sh
