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

See the [full API reference on HexDocs](https://hexdocs.pm/tela) for callbacks, commands, key
structs, frames, and styles.

## Components

- [`Tela.Component.Spinner`](https://hexdocs.pm/tela/Tela.Component.Spinner.html) — animated
  spinner widget with 12 presets; see `examples/spinners.ex`
- [`Tela.Component.TextInput`](https://hexdocs.pm/tela/Tela.Component.TextInput.html) —
  single-line text input with cursor navigation, blink, and password masking; see
  `examples/text_input.ex`, `examples/text_inputs.ex`

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
