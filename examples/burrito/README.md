# Grocery — Burrito example

A grocery list TUI built with Tela, packaged as a self-contained binary using
[Burrito](https://github.com/burrito-elixir/burrito).

This example demonstrates how to wrap a Tela application with Burrito for
single-binary distribution.

## Usage

| Key | Action |
|---|---|
| `j` / `↓` | Move cursor down |
| `k` / `↑` | Move cursor up |
| `space` / `enter` | Toggle selection |
| `q` / `Ctrl+C` | Quit |

## Building

### Prerequisite: custom ERTS

Burrito's default pre-compiled ERTS for Linux is built without termcap support.
Raw terminal mode (required by Tela) depends on termcap. You must supply a
custom ERTS tarball built with termcap enabled.

Build one from the OTP source tree:

```sh
# --with-termcap is the default when ncurses/termcap headers are present;
# this flag makes it explicit and fails fast if the headers are missing.
./configure --with-termcap
make
```

The output is an ERTS tarball of the form `otp-<version>-<os>-<cpu>.tar.gz`.
Point `LINUX_ERTS_PATH` at it.

### Build the binary

```sh
export LINUX_ERTS_PATH=/path/to/otp-28.x.x-linux-x86_64.tar.gz

cd examples/burrito
mix deps.get
MIX_ENV=prod mix release
```

The wrapped binary is written to `burrito_out/grocery_linux`.

### Run

```sh
./burrito_out/grocery_linux
```

On first run Burrito extracts the release to
`~/.local/share/.burrito/grocery_erts-<version>_0.1.0/`. Subsequent runs skip
extraction and start immediately.

## Why a custom ERTS?

Burrito's pre-compiled ERTS for Linux is built against musl libc without
termcap (`/* #undef HAVE_TERMCAP */`).

Without termcap, `prim_tty`'s `tty_init` NIF unconditionally returns `enotsup`
for any raw mode request, making `:shell.start_interactive({:noshell, :raw})`
fail regardless of whether stdin is a TTY. Tela surfaces this as:

```
** (RuntimeError) Tela could not enter raw terminal mode: :enotsup
```

A custom ERTS built with termcap resolves this.
