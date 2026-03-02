defmodule Tela.Component do
  @moduledoc """
  Behaviour for reusable Tela UI components.

  A component is a self-contained, pure widget: it owns its own state struct
  and exposes three callbacks — `c:init/1`, `c:handle_event/2`, and `c:view/1`
  — mirroring the shape of the top-level `Tela` behaviour. Components are
  embedded in a parent model; the parent is responsible for forwarding key
  events and side-effect messages to the component.

  ## Usage

      defmodule MyWidget do
        use Tela.Component

        @impl Tela.Component
        def init(opts), do: %{value: Keyword.get(opts, :value, "")}

        @impl Tela.Component
        def handle_event(model, _key), do: {model, nil}

        @impl Tela.Component
        def view(model), do: Tela.Frame.new(model.value)
      end

  ## Contract

  ### `c:init/1`

  Receives a keyword list of options and returns the initial component model.
  Returns a plain model — **not** `{model, cmd}`. Components do not fire
  startup commands; the parent is responsible for any initial cmd (such as
  starting a spinner tick via `Tela.Component.Spinner.tick_cmd/1`).

  ### `c:handle_event/2`

  Receives the component model and a `Tela.Key` struct. Returns
  `{new_model, cmd}`. Must be a pure function.

  Display-only components (such as `Tela.Component.Spinner`) always return
  `{model, nil}`.

  ### `c:view/1`

  Receives the component model and returns a `Tela.Frame.t()`. Must be a pure
  function. Compose multiple component frames with `Tela.Frame.join/2` in the
  parent's `view/1`.

  ## Side-effect messages

  Components that produce side effects (e.g. animation ticks) expose a
  dedicated handler function outside the behaviour — for example,
  `Tela.Component.Spinner.handle_tick/2`. The parent routes relevant messages
  from `handle_info/2` to the component's handler and merges the returned cmd.
  """

  @doc """
  Called once to initialise the component. Returns the initial model.

  Receives a keyword list of options. Returns a plain model term — not a
  `{model, cmd}` tuple. Any startup commands (such as an initial tick) must
  be launched by the parent.
  """
  @callback init(opts :: keyword()) :: model :: term()

  @doc """
  Called for key events forwarded by the parent.

  Returns `{new_model, cmd}`. Must be a pure function.
  """
  @callback handle_event(model :: term(), key :: Tela.Key.t()) :: {term(), Tela.cmd()}

  @doc """
  Called by the parent's `view/1` to render the component.

  Returns a `Tela.Frame.t()` containing the component's rendered content and
  an optional cursor position relative to the component's own top-left. Must
  be a pure function.

  Parents compose child frames using `Tela.Frame.join/2`, which adjusts
  cursor row offsets automatically.
  """
  @callback view(model :: term()) :: Tela.Frame.t()

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Tela.Component
    end
  end
end
