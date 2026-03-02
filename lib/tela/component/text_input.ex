defmodule Tela.Component.TextInput do
  @moduledoc """
  A single-line text input component.

  `Tela.Component.TextInput` accepts printable character input and supports
  cursor navigation, deletion, and optional password masking. It respects
  focus state — when blurred, key events are ignored and the cursor is hidden.

  ## Usage

      defmodule MyApp do
        use Tela
        alias Tela.Component.TextInput
        alias Tela.Frame

        @impl Tela
        def init(_args) do
          ti = TextInput.init(placeholder: "Pikachu", char_limit: 156) |> TextInput.focus()
          {%{input: ti}, TextInput.blink_cmd(ti)}
        end

        @impl Tela
        def handle_event(model, %Tela.Key{key: key}) when key in [:enter, :escape, {:ctrl, "c"}] do
          {model, :quit}
        end

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
          header = Frame.new("What's your favorite Pokémon?\\n\\n")
          footer = Frame.new("\\n\\n(esc to quit)")
          Frame.join([header, TextInput.view(model.input), footer], separator: "")
        end
      end

  ## Focus

  A `TextInput` is blurred by default. Call `focus/1` to enable input and show
  the cursor. Call `blur/1` to hide the cursor and stop accepting key events.
  In a multi-field form, only one input should be focused at a time.

  ## Cursor

  `TextInput` uses a **virtual cursor** — a reverse-video character embedded
  directly in the `content` string at the cursor position. The frame returned
  by `view/1` always has `cursor: nil`; the real terminal cursor is kept hidden
  so it does not overwrite the virtual cursor's colour.

  The cursor character is the grapheme under the cursor (or a space when the
  cursor is past the last grapheme), rendered with
  `Style.reverse(focused_style)`. This produces a coloured reverse-video block
  that inherits the focused colour.

  Cursor visibility is controlled by `cursor_mode`:

  - `:blink` — the cursor blinks on and off every 530 ms (default). The
    application timer drives this by toggling `cursor_visible`, which gates
    whether the reverse-video character appears in `content`.
  - `:static` — the cursor is always visible.
  - `:hidden` — no cursor character is embedded in `content`.

  Use `blink_cmd/1` to start the blink loop and `handle_blink/2` to process
  tick messages. The stale-tick guard (same pattern as `Tela.Component.Spinner`)
  ensures that in-flight blink tasks from a previous mode or replaced input are
  silently discarded. Use `set_cursor_mode/2` to change modes at runtime.

  ## Echo modes

  Set `echo_mode:` to control how the value is displayed:

  - `:normal` — characters rendered as typed (default).
  - `:password` — each character replaced by `echo_char` (default `"*"`). Pass
    `echo_char: "•"` for a bullet. The underlying value is stored unmasked and
    returned by `value/1`.
  - `:none` — nothing is rendered; the input acts as a fully invisible field.
    Useful for pinentry-style inputs. The underlying value is still stored and
    returned unmasked by `value/1`.

  ## Styling

  `focused_style` and `blurred_style` are `Tela.Style.t()` values applied to
  the prompt and text depending on focus state. Both default to `Tela.Style.new()`.

  """

  use Tela.Component

  alias Tela.Frame
  alias Tela.Style

  @blink_interval_ms 530

  @typedoc """
  The text input model. Build with `init/1`; treat as opaque.
  """
  @type t :: %__MODULE__{
          value: String.t(),
          cursor: non_neg_integer(),
          prompt: String.t(),
          placeholder: String.t(),
          char_limit: non_neg_integer(),
          echo_mode: :normal | :password | :none,
          echo_char: String.t(),
          focused: boolean(),
          cursor_mode: :blink | :static | :hidden,
          cursor_visible: boolean(),
          cursor_id: non_neg_integer(),
          focused_style: Style.t(),
          blurred_style: Style.t()
        }

  defstruct [
    :value,
    :cursor,
    :prompt,
    :placeholder,
    :char_limit,
    :echo_mode,
    :echo_char,
    :focused,
    :cursor_mode,
    :cursor_visible,
    :cursor_id,
    :focused_style,
    :blurred_style
  ]

  @placeholder_style Style.foreground(Style.new(), :bright_black)

  @doc """
  Initialises a new text input model.

  ## Options

  - `prompt:` — prefix rendered before the input text (default `"> "`).
  - `placeholder:` — text shown when value is empty and the input is blurred
    (default `""`).
  - `char_limit:` — maximum number of graphemes accepted; `0` means no limit
    (default `0`).
  - `echo_mode:` — `:normal`, `:password`, or `:none`. Password mode masks each
    character with `echo_char`. None mode renders nothing (default `:normal`).
  - `echo_char:` — the masking character used in password mode (default `"*"`).
  - `cursor_mode:` — `:blink`, `:static`, or `:hidden` (default `:blink`).
  - `focused_style:` — `Tela.Style.t()` applied to prompt and text when focused
    (default `Tela.Style.new()`).
  - `blurred_style:` — `Tela.Style.t()` applied to prompt and text when blurred
    (default `Tela.Style.new()`).
  """
  @impl Tela.Component
  @spec init(keyword()) :: t()
  def init(opts) do
    %__MODULE__{
      value: "",
      cursor: 0,
      prompt: Keyword.get(opts, :prompt, "> "),
      placeholder: Keyword.get(opts, :placeholder, ""),
      char_limit: Keyword.get(opts, :char_limit, 0),
      echo_mode: Keyword.get(opts, :echo_mode, :normal),
      echo_char: Keyword.get(opts, :echo_char, "*"),
      focused: false,
      cursor_mode: Keyword.get(opts, :cursor_mode, :blink),
      cursor_visible: true,
      cursor_id: :erlang.unique_integer([:positive, :monotonic]),
      focused_style: Keyword.get(opts, :focused_style, Style.new()),
      blurred_style: Keyword.get(opts, :blurred_style, Style.new())
    }
  end

  @doc """
  Focuses the input, enabling key events and showing the cursor.
  """
  @spec focus(t()) :: t()
  def focus(%__MODULE__{} = ti), do: %{ti | focused: true}

  @doc """
  Blurs the input, disabling key events and hiding the cursor.
  """
  @spec blur(t()) :: t()
  def blur(%__MODULE__{} = ti), do: %{ti | focused: false}

  @doc """
  Returns the current value of the input.
  """
  @spec value(t()) :: String.t()
  def value(%__MODULE__{value: v}), do: v

  @doc """
  Replaces the current value, clamping to `char_limit` if set, and moves the
  cursor to the end of the new value.
  """
  @spec set_value(t(), String.t()) :: t()
  def set_value(%__MODULE__{} = ti, str) do
    graphemes = String.graphemes(str)

    graphemes =
      if ti.char_limit > 0, do: Enum.take(graphemes, ti.char_limit), else: graphemes

    value = Enum.join(graphemes)
    %{ti | value: value, cursor: length(graphemes)}
  end

  @doc """
  Sets the cursor mode.

  Accepted values: `:blink`, `:static`, `:hidden`.

  Rotates `cursor_id` so any in-flight blink task from the previous mode
  becomes stale and is silently discarded by `handle_blink/2`. Resets
  `cursor_visible` to `true` so that switching back to `:blink` starts with
  the cursor shown.
  """
  @spec set_cursor_mode(t(), :blink | :static | :hidden) :: t()
  def set_cursor_mode(%__MODULE__{} = ti, mode) do
    %{ti | cursor_mode: mode, cursor_visible: true, cursor_id: :erlang.unique_integer([:positive, :monotonic])}
  end

  @doc """
  Returns a `{:task, fun}` cmd that sleeps #{@blink_interval_ms} ms then
  sends `{:text_input_blink, id}` back to the runtime.

  Returns `nil` when `cursor_mode` is not `:blink` — no blink loop is needed
  for `:static` or `:hidden` modes.

  Pass the result as the cmd in your app's `init/1` or `handle_info/2` return.
  Route the resulting tick message to `handle_blink/2`.
  """
  @spec blink_cmd(t()) :: Tela.cmd()
  def blink_cmd(%__MODULE__{cursor_mode: :blink, cursor_id: id}) do
    {:task,
     fn ->
       Process.sleep(@blink_interval_ms)
       {:text_input_blink, id}
     end}
  end

  def blink_cmd(%__MODULE__{}), do: nil

  @doc """
  Processes a blink tick message for this input.

  Matches `{:text_input_blink, id}` where `id` equals the input's current
  `cursor_id`. On a match, toggles `cursor_visible`, rotates `cursor_id`, and
  returns `{new_input, blink_cmd(new_input)}` to re-arm the loop.

  Any non-matching message — including stale ticks from a previous mode or a
  replaced input — returns `{input, nil}` unchanged.
  """
  @spec handle_blink(t(), term()) :: {t(), Tela.cmd()}
  def handle_blink(%__MODULE__{cursor_id: id} = ti, {:text_input_blink, id}) do
    new_ti = %{ti | cursor_visible: not ti.cursor_visible, cursor_id: :erlang.unique_integer([:positive, :monotonic])}
    {new_ti, blink_cmd(new_ti)}
  end

  def handle_blink(%__MODULE__{} = ti, _msg), do: {ti, nil}

  @doc """
  Handles a key event. Returns `{new_model, cmd}`.

  Key events are ignored when the input is blurred. When `cursor_mode` is
  `:blink`, any focused keypress resets the cursor to visible and re-arms the
  blink timer, so the cursor is always immediately visible after typing or
  navigating.
  """
  @impl Tela.Component
  @spec handle_event(t(), Tela.Key.t()) :: {t(), Tela.cmd()}
  def handle_event(%__MODULE__{focused: false} = ti, %Tela.Key{}), do: {ti, nil}

  def handle_event(%__MODULE__{} = ti, %Tela.Key{key: key}) do
    new_ti = ti |> apply_key(key) |> reset_blink()
    {new_ti, blink_cmd(new_ti)}
  end

  defp reset_blink(%__MODULE__{cursor_mode: :blink} = ti) do
    %{ti | cursor_visible: true, cursor_id: :erlang.unique_integer([:positive, :monotonic])}
  end

  defp reset_blink(%__MODULE__{} = ti), do: ti

  @doc """
  Renders the input as a `Tela.Frame`.

  Uses a virtual cursor — a reverse-video character embedded in the `content`
  string at the cursor position. The frame `cursor` is always `nil`; the real
  terminal cursor is kept hidden so it does not overwrite the virtual cursor's
  colour.

  When the cursor is visible (focused, `cursor_mode` not `:hidden`, and blink
  phase on), the grapheme under the cursor — or a space when the cursor is past
  the last grapheme — is rendered with `Style.reverse(focused_style)`. This
  produces a coloured reverse-video block that inherits the focused colour.

  When blurred, `cursor_mode` is `:hidden`, or the blink phase is off, no
  cursor character is embedded and `content` is the plain styled text.
  """
  @impl Tela.Component
  @spec view(t()) :: Frame.t()
  def view(%__MODULE__{} = ti) do
    graphemes = display_graphemes(ti)
    cursor_visible = cursor_visible?(ti)
    content = render_content(ti, graphemes, cursor_visible)
    Frame.new(content)
  end

  defp cursor_visible?(%__MODULE__{focused: false}), do: false
  defp cursor_visible?(%__MODULE__{cursor_mode: :hidden}), do: false
  defp cursor_visible?(%__MODULE__{cursor_mode: :blink, cursor_visible: false}), do: false
  defp cursor_visible?(%__MODULE__{}), do: true

  defp render_content(%__MODULE__{focused: false} = ti, graphemes, _cursor_visible) do
    if graphemes == [] and ti.placeholder != "" do
      prompt_part =
        if ti.blurred_style == Style.new(),
          do: ti.prompt,
          else: Style.render(ti.blurred_style, ti.prompt)

      prompt_part <> Style.render(@placeholder_style, ti.placeholder)
    else
      text = Enum.join(graphemes)

      if ti.blurred_style == Style.new() do
        ti.prompt <> text
      else
        Style.render(ti.blurred_style, ti.prompt <> text)
      end
    end
  end

  defp render_content(%__MODULE__{focused: true} = ti, graphemes, cursor_visible) do
    if graphemes == [] and ti.placeholder != "" do
      render_focused_placeholder(ti, cursor_visible)
    else
      render_focused_with_cursor(ti, graphemes, cursor_visible)
    end
  end

  # Renders the focused prompt + placeholder, embedding a reverse-video cursor
  # char on the first grapheme of the placeholder when cursor_visible is true.
  defp render_focused_placeholder(%__MODULE__{} = ti, false) do
    prompt_part =
      if ti.focused_style == Style.new(),
        do: ti.prompt,
        else: Style.render(ti.focused_style, ti.prompt)

    prompt_part <> Style.render(@placeholder_style, ti.placeholder)
  end

  defp render_focused_placeholder(%__MODULE__{} = ti, true) do
    prompt_part =
      if ti.focused_style == Style.new(),
        do: ti.prompt,
        else: Style.render(ti.focused_style, ti.prompt)

    [first | rest] = String.graphemes(ti.placeholder)
    cursor_str = Style.render(Style.reverse(ti.focused_style), first)
    rest_str = if rest == [], do: "", else: Style.render(@placeholder_style, Enum.join(rest))
    prompt_part <> cursor_str <> rest_str
  end

  # Renders the focused prompt + text, embedding a reverse-video cursor char
  # at the cursor position when cursor_visible is true.
  defp render_focused_with_cursor(%__MODULE__{} = ti, graphemes, false) do
    text = Enum.join(graphemes)

    if ti.focused_style == Style.new() do
      ti.prompt <> text
    else
      if text == "" do
        Style.render(ti.focused_style, ti.prompt)
      else
        Style.render(ti.focused_style, ti.prompt <> text)
      end
    end
  end

  defp render_focused_with_cursor(%__MODULE__{} = ti, graphemes, true) do
    display_cursor = min(ti.cursor, length(graphemes))
    {before_g, at_and_after} = Enum.split(graphemes, display_cursor)
    {cursor_g, after_g} = split_cursor_char(at_and_after)

    cursor_char_style = Style.reverse(ti.focused_style)

    before_str = render_segment(ti.focused_style, ti.prompt <> Enum.join(before_g))
    cursor_str = Style.render(cursor_char_style, cursor_g)
    after_str = render_segment(ti.focused_style, Enum.join(after_g))

    before_str <> cursor_str <> after_str
  end

  # Returns {cursor_char, rest}. Uses a space when the cursor is past the last grapheme.
  defp split_cursor_char([char | rest]), do: {char, rest}
  defp split_cursor_char([]), do: {" ", []}

  # Renders a string segment with the given style. Returns the plain string when
  # the style is the default (no attributes) or the string is empty.
  defp render_segment(_style, ""), do: ""

  defp render_segment(style, str) do
    if style == Style.new(), do: str, else: Style.render(style, str)
  end

  defp display_graphemes(%__MODULE__{echo_mode: :none}), do: []

  defp display_graphemes(%__MODULE__{value: value, echo_mode: :password, echo_char: echo_char}) do
    value |> String.graphemes() |> Enum.map(fn _ -> echo_char end)
  end

  defp display_graphemes(%__MODULE__{value: value}) do
    String.graphemes(value)
  end

  defp apply_key(ti, {:char, char}), do: insert(ti, char)
  defp apply_key(ti, :backspace), do: delete_before(ti)
  # ctrl+h (0x08) is the BS byte sent by some terminals in place of DEL (0x7F)
  defp apply_key(ti, {:ctrl, "h"}), do: delete_before(ti)
  defp apply_key(ti, :delete), do: delete_at(ti)
  defp apply_key(ti, {:ctrl, "d"}), do: delete_at(ti)
  defp apply_key(ti, {:ctrl, "k"}), do: delete_to_end(ti)
  defp apply_key(ti, {:ctrl, "u"}), do: delete_to_start(ti)
  defp apply_key(ti, {:ctrl, "w"}), do: delete_word_backward(ti)
  defp apply_key(ti, {:alt, "d"}), do: delete_word_forward(ti)
  defp apply_key(ti, :left), do: move_left(ti)
  defp apply_key(ti, {:ctrl, "b"}), do: move_left(ti)
  defp apply_key(ti, :right), do: move_right(ti)
  defp apply_key(ti, {:ctrl, "f"}), do: move_right(ti)
  defp apply_key(ti, {:alt, "f"}), do: move_word_right(ti)
  defp apply_key(ti, {:alt, "b"}), do: move_word_left(ti)
  defp apply_key(ti, :home), do: %{ti | cursor: 0}
  defp apply_key(ti, {:ctrl, "a"}), do: %{ti | cursor: 0}
  defp apply_key(ti, :end), do: %{ti | cursor: grapheme_length(ti.value)}
  defp apply_key(ti, {:ctrl, "e"}), do: %{ti | cursor: grapheme_length(ti.value)}
  defp apply_key(ti, _), do: ti

  defp insert(ti, char) do
    graphemes = String.graphemes(ti.value)
    len = length(graphemes)

    if ti.char_limit > 0 and len >= ti.char_limit do
      ti
    else
      {before, after_} = Enum.split(graphemes, ti.cursor)
      new_value = Enum.join(before ++ [char] ++ after_)
      %{ti | value: new_value, cursor: ti.cursor + 1}
    end
  end

  defp delete_before(ti) when ti.cursor == 0, do: ti

  defp delete_before(ti) do
    graphemes = String.graphemes(ti.value)
    {before, after_} = Enum.split(graphemes, ti.cursor)
    new_value = Enum.join(Enum.drop(before, -1) ++ after_)
    %{ti | value: new_value, cursor: ti.cursor - 1}
  end

  defp delete_at(ti) do
    graphemes = String.graphemes(ti.value)

    if ti.cursor >= length(graphemes) do
      ti
    else
      {before, after_} = Enum.split(graphemes, ti.cursor)
      new_value = Enum.join(before ++ tl(after_))
      %{ti | value: new_value}
    end
  end

  defp delete_to_end(ti) do
    graphemes = String.graphemes(ti.value)
    new_value = graphemes |> Enum.take(ti.cursor) |> Enum.join()
    %{ti | value: new_value}
  end

  defp delete_to_start(ti) do
    graphemes = String.graphemes(ti.value)
    new_value = graphemes |> Enum.drop(ti.cursor) |> Enum.join()
    %{ti | value: new_value, cursor: 0}
  end

  defp delete_word_backward(ti) when ti.cursor == 0, do: ti

  defp delete_word_backward(ti) do
    graphemes = String.graphemes(ti.value)
    {before, after_} = Enum.split(graphemes, ti.cursor)
    trimmed = before |> Enum.reverse() |> drop_spaces() |> drop_non_spaces() |> Enum.reverse()
    new_value = Enum.join(trimmed ++ after_)
    %{ti | value: new_value, cursor: length(trimmed)}
  end

  defp drop_spaces([" " | rest]), do: drop_spaces(rest)
  defp drop_spaces(list), do: list

  defp drop_non_spaces([" " | _] = list), do: list
  defp drop_non_spaces([_ | rest]), do: drop_non_spaces(rest)
  defp drop_non_spaces([]), do: []

  defp delete_word_forward(%__MODULE__{echo_mode: mode} = ti) when mode != :normal do
    delete_to_end(ti)
  end

  defp delete_word_forward(ti) do
    graphemes = String.graphemes(ti.value)
    len = length(graphemes)

    if ti.cursor >= len do
      ti
    else
      end_pos =
        ti.cursor
        |> then(fn p -> advance_while(graphemes, p, len, &(&1 == " ")) end)
        |> then(fn p -> advance_while(graphemes, p, len, &(&1 != " ")) end)

      new_graphemes = Enum.take(graphemes, ti.cursor) ++ Enum.drop(graphemes, end_pos)
      %{ti | value: Enum.join(new_graphemes)}
    end
  end

  defp move_word_right(%__MODULE__{echo_mode: mode} = ti) when mode != :normal do
    %{ti | cursor: grapheme_length(ti.value)}
  end

  defp move_word_right(ti) do
    graphemes = String.graphemes(ti.value)
    len = length(graphemes)

    if ti.cursor >= len do
      ti
    else
      new_pos =
        ti.cursor
        |> then(fn p -> advance_while(graphemes, p, len, &(&1 == " ")) end)
        |> then(fn p -> advance_while(graphemes, p, len, &(&1 != " ")) end)

      %{ti | cursor: new_pos}
    end
  end

  defp advance_while(graphemes, pos, len, pred) do
    if pos < len and pred.(Enum.at(graphemes, pos)),
      do: advance_while(graphemes, pos + 1, len, pred),
      else: pos
  end

  defp move_word_left(%__MODULE__{echo_mode: mode} = ti) when mode != :normal do
    %{ti | cursor: 0}
  end

  defp move_word_left(ti) do
    if ti.cursor == 0 do
      ti
    else
      graphemes = String.graphemes(ti.value)

      new_pos =
        ti.cursor
        |> then(fn p -> recede_while(graphemes, p, &(&1 == " ")) end)
        |> then(fn p -> recede_while(graphemes, p, &(&1 != " ")) end)

      %{ti | cursor: new_pos}
    end
  end

  defp recede_while(graphemes, pos, pred) do
    if pos > 0 and pred.(Enum.at(graphemes, pos - 1)),
      do: recede_while(graphemes, pos - 1, pred),
      else: pos
  end

  defp move_left(ti), do: %{ti | cursor: max(0, ti.cursor - 1)}
  defp move_right(ti), do: %{ti | cursor: min(grapheme_length(ti.value), ti.cursor + 1)}

  defp grapheme_length(str), do: str |> String.graphemes() |> length()
end
