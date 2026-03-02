# Tela

---

[![Hex.pm](https://img.shields.io/hexpm/v/tela.svg)](https://hex.pm/packages/tela) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/tela/)

A zero-dependency Elixir library for building interactive terminal UIs using the
[Elm Architecture](https://guide.elm-lang.org/architecture/).

```
         args
           │
           ▼
        init/1
           │
           ▼
    ┌─────model─────┐
    │               │
    ▼               │
 view/1          handle_event/2   ◄── key events from stdin
    │            handle_info/2    ◄── cmd results, timer ticks, external messages
    │               │
    ▼               ▼
 Frame.t()     {new_model, cmd}
    │
    ▼
 rendered to stdout (diff only)
```

Inspired by [Bubble Tea](https://github.com/charmbracelet/bubbletea). Designed to feel familiar
to Elixir developers through a callback interface modelled on `GenServer` and `Phoenix.LiveView`.

## Features

- **Zero runtime dependencies** — built entirely on OTP 28 stdlib
- **Plain library** — no `Application` callback, no hidden processes; you own supervision
- **Pure callbacks** — `init/1`, `handle_event/2`, `handle_info/2`, and `view/1` are pure
  functions; test your UI logic without starting a terminal
- **Diff rendering** — only changed lines are written to stdout
- **Composable styles** — ANSI colours, bold, italic, borders via `Tela.Style`
- **Built-in components** — `Tela.Component.Spinner` and `Tela.Component.TextInput`

## Requirements

- Elixir `~> 1.19`
- OTP 28 (uses `shell.start_interactive/1` for raw terminal mode, introduced in OTP 28)

## Installation

```elixir
def deps do
  [
    {:tela, "~> 0.1"}
  ]
end
```

## Quick start

```elixir
defmodule Counter do
  use Tela

  @impl Tela
  def init(_args), do: {0, nil}

  @impl Tela
  def handle_event(count, %Tela.Key{key: {:char, "k"}}), do: {count + 1, nil}
  def handle_event(count, %Tela.Key{key: {:char, "j"}}), do: {count - 1, nil}
  def handle_event(count, %Tela.Key{key: {:char, "q"}}), do: {count, :quit}
  def handle_event(count, _key), do: {count, nil}

  @impl Tela
  def handle_info(count, _msg), do: {count, nil}

  @impl Tela
  def view(count) do
    Tela.Frame.new("Count: #{count}\n\nk = increment  j = decrement  q = quit")
  end
end

{:ok, final_count} = Tela.run(Counter, [])
IO.puts("Final count: #{final_count}")
```

Run it:

```sh
mix run -e "Tela.run(Counter, [])"
```

## Callbacks

### `init/1`

```elixir
@callback init(args :: term()) :: {model :: term(), Tela.cmd()}
```

Called once at startup. Returns `{initial_model, cmd}`. Use `{:task, fun}` to kick off background
work, or `nil` for no side effect.

### `handle_event/2`

```elixir
@callback handle_event(model :: term(), key :: Tela.Key.t()) :: {term(), Tela.cmd()}
```

Called for every keystroke from stdin. Must be pure — no side effects.

### `handle_info/2`

```elixir
@callback handle_info(model :: term(), msg :: term()) :: {term(), Tela.cmd()}
```

Called for cmd results, timer ticks, and any message sent to the runtime process via
`Process.send/2`. Must be pure.

### `view/1`

```elixir
@callback view(model :: term()) :: Tela.Frame.t()
```

Called after every update. Returns a `Tela.Frame.t()`. The runtime diffs the content against the
previous frame and writes only changed lines.

## Commands

```elixir
@type cmd :: nil | :quit | {:task, (() -> term())}
```

- `nil` — no side effect
- `:quit` — stop the runtime and restore the terminal
- `{:task, fun}` — run `fun` in a separate process; its return value is delivered to
  `handle_info/2`

## Keys

Every keystroke arrives as a `%Tela.Key{key: key, raw: binary()}`. Pattern match on `key`:

```elixir
# Printable characters
%Tela.Key{key: {:char, "a"}}

# Control keys
%Tela.Key{key: {:ctrl, "c"}}
%Tela.Key{key: {:alt, "f"}}

# Named keys
%Tela.Key{key: :enter}
%Tela.Key{key: :backspace}
%Tela.Key{key: :up}
%Tela.Key{key: :down}
%Tela.Key{key: :left}
%Tela.Key{key: :right}
%Tela.Key{key: :escape}
%Tela.Key{key: :tab}
%Tela.Key{key: :shift_tab}
%Tela.Key{key: :home}
%Tela.Key{key: :end}
%Tela.Key{key: :page_up}
%Tela.Key{key: :page_down}
%Tela.Key{key: {:f, 1}}      # F1–F12

# Unknown byte sequences
%Tela.Key{key: :unknown}
```

> **Note:** Always match `{:char, "q"}`, never a bare `"q"`. The latter will never match.

## Frames and layout

`Tela.Frame.new/1` wraps a string (lines separated by `\n`) into a frame. Frames compose
vertically with `Frame.join/2`:

```elixir
alias Tela.Frame

header = Frame.new("My App\n")
body   = Frame.new("Content here")
footer = Frame.new("\n\nq to quit")

frame = Frame.join([header, body, footer], separator: "")
```

`Frame.join/2` adjusts cursor row offsets automatically, so components that expose a cursor
position remain correct when embedded in a larger layout.

### Real terminal cursor

Pass a `cursor:` option to `Frame.new/2` to position the real terminal cursor:

```elixir
Frame.new("Hello", cursor: {0, 3, :block})
#                            row col shape
```

Shapes: `:block`, `:bar`, `:underline`. Use `nil` (the default) to hide the cursor.

## Styles

`Tela.Style` produces composable ANSI style structs. All functions are pure.

```elixir
alias Tela.Style

style =
  Style.new()
  |> Style.bold()
  |> Style.foreground(:cyan)
  |> Style.background(:black)
  |> Style.border(:rounded)
  |> Style.padding(1, 2)

Style.render(style, "Hello, world!")
```

**Text attributes:** `bold/1`, `dim/1`, `italic/1`, `underline/1`, `strikethrough/1`, `reverse/1`

**Colours:** `:black`, `:red`, `:green`, `:yellow`, `:blue`, `:magenta`, `:cyan`, `:white`,
`bright_` variants (e.g. `:bright_cyan`), and `:default`

**Borders:** `:single`, `:double`, `:rounded`, `:thick`

**Padding:** `padding(style, all)`, `padding(style, vertical, horizontal)`,
`padding(style, top, right, bottom, left)`

Use `Style.width/1` to measure the visible width of a styled string (strips ANSI escapes).

## Components

### Spinner

```elixir
alias Tela.Component.Spinner

defmodule Loading do
  use Tela

  @impl Tela
  def init(_) do
    spinner = Spinner.init(spinner: :dot)
    {%{spinner: spinner, done: false}, Spinner.tick_cmd(spinner)}
  end

  @impl Tela
  def handle_event(model, %Tela.Key{key: {:char, "q"}}), do: {model, :quit}
  def handle_event(model, _key), do: {model, nil}

  @impl Tela
  def handle_info(model, msg) do
    {spinner, cmd} = Spinner.handle_tick(model.spinner, msg)
    {%{model | spinner: spinner}, cmd}
  end

  @impl Tela
  def view(model) do
    Tela.Frame.new(Spinner.view(model.spinner).content <> " Loading...  q to quit")
  end
end
```

**Presets:** `:line`, `:dot`, `:mini_dot`, `:jump`, `:pulse`, `:points`, `:globe`, `:moon`,
`:monkey`, `:meter`, `:hamburger`, `:ellipsis`

Custom spinner: pass `spinner: {frames_list, interval_ms}`.

The parent owns the tick loop. Call `Spinner.tick_cmd/1` from `init/1` and re-arm from
`handle_info/2` by passing the result of `Spinner.handle_tick/2` as your cmd. Stale ticks
(arriving after a spinner is replaced) are silently dropped.

### TextInput

```elixir
alias Tela.Component.TextInput
alias Tela.Frame

defmodule Search do
  use Tela

  @impl Tela
  def init(_) do
    input = TextInput.init(placeholder: "Search...", char_limit: 100) |> TextInput.focus()
    {%{input: input}, TextInput.blink_cmd(input)}
  end

  @impl Tela
  def handle_event(model, %Tela.Key{key: :escape}), do: {model, :quit}

  def handle_event(model, key) do
    {input, cmd} = TextInput.handle_event(model.input, key)
    {%{model | input: input}, cmd}
  end

  @impl Tela
  def handle_info(model, msg) do
    {input, cmd} = TextInput.handle_blink(model.input, msg)
    {%{model | input: input}, cmd}
  end

  @impl Tela
  def view(model) do
    Frame.join(
      [Frame.new("Query:\n\n"), TextInput.view(model.input), Frame.new("\n\nesc to quit")],
      separator: ""
    )
  end
end

{:ok, model} = Tela.run(Search, [])
IO.puts("Searched for: #{TextInput.value(model.input)}")
```

**Key bindings:**

| Key | Action |
|---|---|
| `{:char, c}` | Insert character |
| `:backspace` / `{:ctrl, "h"}` | Delete before cursor |
| `:delete` / `{:ctrl, "d"}` | Delete at cursor |
| `{:ctrl, "k"}` | Delete to end of line |
| `{:ctrl, "u"}` | Delete to start of line |
| `{:ctrl, "w"}` | Delete word backward |
| `{:alt, "d"}` | Delete word forward |
| `:left` / `{:ctrl, "b"}` | Move left one character |
| `:right` / `{:ctrl, "f"}` | Move right one character |
| `{:alt, "b"}` | Move left one word |
| `{:alt, "f"}` | Move right one word |
| `:home` / `{:ctrl, "a"}` | Jump to start |
| `:end` / `{:ctrl, "e"}` | Jump to end |

**Options:** `placeholder`, `char_limit`, `echo_mode` (`:normal`, `:password`, `:none`),
`echo_char`, `focused_style`, `blurred_style`

**Cursor modes:** `:blink` (default), `:static`, `:hidden` — change with `set_cursor_mode/2`.
TextInput uses a virtual cursor (reverse-video character embedded in content); the real terminal
cursor stays hidden.

## Timers and background work

Any `{:task, fun}` cmd spawns `fun` in a separate process. The return value is sent back to
the runtime and delivered to `handle_info/2`. This is how timers work:

```elixir
# A tick that fires every 16ms
def tick_cmd, do: {:task, fn -> Process.sleep(16); :tick end}

def init(_), do: {initial_model(), tick_cmd()}

def handle_info(model, :tick) do
  {update(model), tick_cmd()}   # re-arm
end

def handle_info(model, _msg), do: {model, nil}
```

## External processes

Capture `self()` before calling `Tela.run/2`; that pid is the runtime process. External
processes can send messages to it directly:

```elixir
runtime_pid = self()

Task.start(fn ->
  Stream.interval(1000)
  |> Enum.each(fn i -> send(runtime_pid, {:tick, i}) end)
end)

Tela.run(MyApp, [])
```

Messages arrive in `handle_info/2`.

## Reading results

`Tela.run/2` blocks until the program quits and returns `{:ok, final_model}`:

```elixir
{:ok, model} = Tela.run(Picker, items: ["one", "two", "three"])
IO.puts("You chose: #{model.selected}")
```

## Testing

Because all callbacks are pure functions, test them directly — no terminal or runtime needed:

```elixir
defmodule CounterTest do
  use ExUnit.Case

  test "increment" do
    {model, cmd} = Counter.init([])
    {model, _cmd} = Counter.handle_event(model, %Tela.Key{key: {:char, "k"}, raw: "k"})
    assert model == 1
    assert cmd == nil
  end

  test "quit" do
    {model, cmd} = Counter.handle_event(0, %Tela.Key{key: {:char, "q"}, raw: "q"})
    assert cmd == :quit
  end
end
```

## Examples

The `examples/` directory contains runnable scripts:

| File | Demonstrates |
|---|---|
| `result.ex` | Reading `{:ok, model}` after quit |
| `spinners.ex` | All 12 spinner presets, runtime swapping |
| `realtime.ex` | External process sending events to the runtime |
| `stopwatch.ex` | Start/stop tick loop, millisecond timer |
| `timer.ex` | Automatic `:quit` from `handle_info/2` |
| `debounce.ex` | Debounce pattern using stale-task guards |
| `text_input.ex` | Single `TextInput` field with placeholder and blink |
| `text_inputs.ex` | Multi-field form with tab navigation and password masking |
| `burrito/` | Self-contained binary via [Burrito](https://github.com/burrito-elixir/burrito) |

Run any example with:

```sh
mix run examples/stopwatch.ex
```

## License

MIT
