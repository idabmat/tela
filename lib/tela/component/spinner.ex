defmodule Tela.Component.Spinner do
  @moduledoc """
  An animated spinner component.

  `Tela.Component.Spinner` is a display-only widget that cycles through a list
  of animation frames at a fixed interval. It is driven by a tick cmd that the
  parent starts via `tick_cmd/1` and routes back via `handle_tick/2`.

  ## Usage

      defmodule MyApp do
        use Tela
        alias Tela.Component.Spinner

        @impl Tela
        def init(_args) do
          spinner = Spinner.init(spinner: :dot)
          {%{spinner: spinner}, Spinner.tick_cmd(spinner)}
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
          Spinner.view(model.spinner) <> " Loading..."
        end
      end

  ## Presets

  The following preset atoms are available:

  - `:line` — `|`, `/`, `-`, `\\`
  - `:dot` — Braille dot spinner
  - `:mini_dot` — smaller Braille dot spinner
  - `:jump` — Braille jump spinner
  - `:pulse` — block pulse `█▓▒░`
  - `:points` — moving dot `∙∙∙ ●∙∙ ∙●∙ ∙∙●`
  - `:globe` — rotating globe emoji
  - `:moon` — moon phase emoji
  - `:monkey` — monkey emoji sequence
  - `:meter` — filling bar `▱▱▱ → ▰▰▰`
  - `:hamburger` — stacked lines `☱ ☲ ☴`
  - `:ellipsis` — growing dots `. .. ...`

  Custom spinners can be passed as a `{frames, interval_ms}` tuple.

  ## Tick ownership

  Components do not emit startup cmds from `init/1`. The parent must call
  `tick_cmd/1` to obtain the initial cmd and include it in its own `init/1`
  return value. The tick self-re-arms: each successful `handle_tick/2` call
  returns a new cmd that advances the animation by one more frame.

  Each spinner is assigned a unique `id` on `init/1`. Ticks carry that id, and
  `handle_tick/2` rejects any tick whose id does not match the current spinner's
  id — silently dropping stale ticks from replaced spinners without needing
  explicit cancellation.
  """

  use Tela.Component

  alias Tela.Style

  @typedoc """
  The spinner model. Build with `init/1`; treat as opaque.
  """
  @type t :: %__MODULE__{
          frames: [String.t()],
          interval_ms: pos_integer(),
          frame: non_neg_integer(),
          id: non_neg_integer(),
          style: Style.t()
        }

  defstruct [:frames, :interval_ms, :frame, :id, :style]

  @presets %{
    line: {["|", "/", "-", "\\"], 100},
    dot: {["⣾ ", "⣽ ", "⣻ ", "⢿ ", "⡿ ", "⣟ ", "⣯ ", "⣷ "], 100},
    mini_dot: {["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"], 83},
    jump: {["⢄", "⢂", "⢁", "⡁", "⡈", "⡐", "⡠"], 100},
    pulse: {["█", "▓", "▒", "░"], 125},
    points: {["∙∙∙", "●∙∙", "∙●∙", "∙∙●"], 143},
    globe: {["🌍", "🌎", "🌏"], 250},
    moon: {["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"], 125},
    monkey: {["🙈", "🙉", "🙊"], 333},
    meter: {["▱▱▱", "▰▱▱", "▰▰▱", "▰▰▰", "▰▰▱", "▰▱▱", "▱▱▱"], 143},
    hamburger: {["☱", "☲", "☴", "☲"], 333},
    ellipsis: {["   ", ".  ", ".. ", "..."], 333}
  }

  @doc """
  Initialises a new spinner model.

  ## Options

  - `spinner:` — a preset atom (default `:line`) or a `{frames, interval_ms}`
    tuple for a custom spinner. See the module doc for available presets.
  - `style:` — a `Tela.Style.t()` applied when rendering (default `Tela.Style.new()`).

  Raises `ArgumentError` if the spinner option is an unrecognised atom.
  """
  @impl Tela.Component
  @spec init(keyword()) :: t()
  def init(opts) do
    {frames, interval_ms} = resolve_spinner(Keyword.get(opts, :spinner, :line))
    style = Keyword.get(opts, :style, Style.new())

    %__MODULE__{
      frames: frames,
      interval_ms: interval_ms,
      frame: 0,
      id: :erlang.unique_integer([:positive, :monotonic]),
      style: style
    }
  end

  @doc """
  Returns the current animation frame as a `Tela.Frame`.

  The frame carries no cursor — `Tela.Component.Spinner` is a display-only
  component. Compose the returned frame with surrounding content using
  `Tela.Frame.join/2` in the parent's `view/1`.
  """
  @impl Tela.Component
  @spec view(t()) :: Tela.Frame.t()
  def view(%__MODULE__{} = spinner) do
    content =
      case Enum.at(spinner.frames, spinner.frame) do
        nil -> ""
        frame -> Style.render(spinner.style, frame)
      end

    Tela.Frame.new(content)
  end

  @doc """
  Returns a `{:task, fun}` cmd that, when dispatched, sleeps for
  `interval_ms` and then returns `{:spinner_tick, id}`.

  Pass the result directly as the cmd in your parent's `init/1` or
  `handle_info/2` return to drive the animation.
  """
  @spec tick_cmd(t()) :: Tela.cmd()
  def tick_cmd(%__MODULE__{} = spinner) do
    id = spinner.id
    ms = spinner.interval_ms

    {:task,
     fn ->
       Process.sleep(ms)
       {:spinner_tick, id}
     end}
  end

  @doc """
  Processes a tick message for this spinner.

  Matches `{:spinner_tick, id}` where `id` equals the spinner's current id. On
  a match, advances the frame by one (wrapping around), assigns a new unique id,
  and returns `{new_spinner, tick_cmd(new_spinner)}`.

  Any non-matching message — including ticks with a stale id from a replaced
  spinner — returns `{spinner, nil}` unchanged.
  """
  @spec handle_tick(t(), term()) :: {t(), Tela.cmd()}
  def handle_tick(%__MODULE__{id: id} = spinner, {:spinner_tick, id}) do
    next_frame = rem(spinner.frame + 1, length(spinner.frames))
    new_spinner = %{spinner | frame: next_frame, id: :erlang.unique_integer([:positive, :monotonic])}
    {new_spinner, tick_cmd(new_spinner)}
  end

  def handle_tick(%__MODULE__{} = spinner, _msg), do: {spinner, nil}

  @doc """
  Ignores all key events. The spinner is display-only.
  """
  @impl Tela.Component
  @spec handle_event(t(), Tela.Key.t()) :: {t(), Tela.cmd()}
  def handle_event(%__MODULE__{} = spinner, %Tela.Key{}), do: {spinner, nil}

  defp resolve_spinner({frames, interval_ms}) when is_list(frames) and is_integer(interval_ms) and interval_ms > 0,
    do: {frames, interval_ms}

  defp resolve_spinner(preset) when is_atom(preset) do
    case @presets[preset] do
      nil ->
        raise ArgumentError,
              "unknown spinner #{inspect(preset)}. " <>
                "Pass a preset atom (#{inspect(Map.keys(@presets))}) or a {frames, interval_ms} tuple."

      value ->
        value
    end
  end

  defp resolve_spinner(other) do
    raise ArgumentError,
          "unknown spinner #{inspect(other)}. " <>
            "Pass a preset atom (#{inspect(Map.keys(@presets))}) or a {frames, interval_ms} tuple."
  end
end
