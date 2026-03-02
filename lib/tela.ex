defmodule Tela do
  @moduledoc """
  Zero-dependency Elixir TUI framework using the Elm Architecture.

  ## Overview

  Tela lets you build interactive terminal applications with a simple,
  testable callback interface modelled on `GenServer` and `Phoenix.LiveView`.
  The runtime handles raw mode, alternate screen, rendering, and cleanup —
  your callbacks stay pure and easy to unit-test.

  ## Quickstart

      defmodule MyApp do
        use Tela

        @impl Tela
        def init(_args), do: {%{count: 0}, nil}

        @impl Tela
        def handle_event(model, %Tela.Key{key: {:char, "q"}}), do: {model, :quit}
        def handle_event(model, %Tela.Key{key: {:char, " "}}), do: {%{model | count: model.count + 1}, nil}
        def handle_event(model, _key), do: {model, nil}

        @impl Tela
        def handle_info(model, _msg), do: {model, nil}

        @impl Tela
        def view(model), do: Tela.Frame.new("Count: \#{model.count}\\nPress <space> to increment, q to quit.")
      end

        {:ok, _model} = MyApp.run()

  ## Callbacks

  All four callbacks are pure functions. You can call them directly in your
  test suite without starting the runtime.

  ### `c:init/1`

  Called once with the args passed to `run/2`. Returns `{initial_model, cmd}`.

  ### `c:handle_event/2`

  Called for every parsed keystroke. Receives the current model and a
  `Tela.Key` struct. Returns `{new_model, cmd}`.

  ### `c:handle_info/2`

  Called for task results and any other messages sent to the runtime process.
  Returns `{new_model, cmd}`.

  ### `c:view/1`

  Called after every state change. Returns a `Tela.Frame` with the full UI
  string (lines separated by `\\n`) and an optional cursor position. The
  runtime diffs against the previous frame and only redraws changed lines,
  then positions the real terminal cursor if one is specified.

  ## Commands

  The `cmd` returned from `handle_event/2` and `handle_info/2` can be:

  - `nil` — no side effect.
  - `:quit` — stop the runtime and restore the terminal.
  - `{:task, fun}` — run `fun/0` in a new process. The return value is
    sent back to the runtime as a message and delivered to `handle_info/2`.

  ## `use Tela`

  `use Tela` injects the `@behaviour` declaration and a `run/1` convenience
  function into your module. You still define all four callbacks yourself.
  """

  @typedoc """
  A command returned from `handle_event/2` or `handle_info/2`.

  - `nil` — no side effect.
  - `:quit` — stop the runtime cleanly.
  - `{:task, fun}` — spawn `fun` in a new process; the return value is
    delivered to `handle_info/2` as `{:task_result, result}`.
  """
  @type cmd :: nil | :quit | {:task, (-> term())}

  @doc """
  Called once at startup. Returns `{initial_model, cmd}`.

  `cmd` is executed immediately after the first render — use `{:task, fun}`
  to kick off background work (e.g. a spinner tick) or `nil` for no side
  effect. Must not perform I/O directly.
  """
  @callback init(args :: term()) :: {model :: term(), Tela.cmd()}

  @doc """
  Called for every parsed keystroke from stdin.

  Returns `{new_model, cmd}`. Must be a pure function.
  """
  @callback handle_event(model :: term(), key :: Tela.Key.t()) :: {term(), Tela.cmd()}

  @doc """
  Called for task results and any other messages delivered to the runtime
  process.

  Returns `{new_model, cmd}`. Must be a pure function.
  """
  @callback handle_info(model :: term(), msg :: term()) :: {term(), Tela.cmd()}

  @doc """
  Called after every state change. Returns a `Tela.Frame` containing the full
  UI string (lines separated by `\\n`) and an optional cursor position.

  Set `cursor:` to `{row, col, shape}` (0-indexed, absolute within the full
  frame) to show the real terminal cursor at that position. Set to `nil` (or
  use `Frame.new/1`) to hide the cursor. Use `Tela.Frame.join/2` to compose
  multiple component frames — it handles cursor row offset arithmetic
  automatically.

  Must be a pure function.
  """
  @callback view(model :: term()) :: Tela.Frame.t()

  @doc """
  Starts the Tela runtime for the given module, passing `args` to `init/1`.

  Blocks until the application quits (via a `:quit` cmd or process exit).
  The terminal is always restored on exit. Returns `{:ok, final_model}` where
  `final_model` is the model at the time the application quit.

  ## Examples

      {:ok, model} = Tela.run(MyApp, [])
      {:ok, model} = Tela.run(MyApp, %{initial_tab: :tasks})
  """
  @spec run(module :: module(), args :: term()) :: {:ok, term()}
  def run(module, args \\ []) do
    Tela.Runtime.run(module, args)
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Tela

      @doc """
      Starts the Tela runtime for this module with the given args.

      Delegates to `Tela.run/2`. Blocks until the application quits.
      Returns `{:ok, final_model}`.
      """
      @spec run(args :: term()) :: {:ok, term()}
      def run(args \\ []) do
        Tela.run(__MODULE__, args)
      end
    end
  end
end
