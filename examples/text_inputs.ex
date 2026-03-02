defmodule TextInputs do
  @moduledoc """
  A multi-field form with focused/blurred styling, a submit button, and
  cycling cursor modes.

  Demonstrates three `Tela.Component.TextInput` components with different
  modes: normal text, email, and password. Tab/down/enter cycle focus forward;
  shift+tab/up cycle backward. Pressing ctrl+r cycles the cursor mode through
  blink → static → hidden across all fields. Pressing enter on the Submit
  button quits.

  Ported from the Bubbletea textinputs example.

  Run with:

      mix run examples/text_inputs.ex

  Controls: tab/down/enter advance focus, shift+tab/up go back,
            ctrl+r cycle cursor mode, ctrl+c/esc quit.
  """

  use Tela

  alias Tela.Component.TextInput, as: TI
  alias Tela.Style

  @focused_style Style.foreground(Style.new(), :magenta)
  @blurred_style Style.foreground(Style.new(), :bright_black)
  @help_style Style.foreground(Style.new(), :bright_black)
  @cursor_mode_help_style Style.foreground(Style.new(), :white)

  @field_count 3
  @cursor_modes [:blink, :static, :hidden]

  defp make_inputs do
    [
      [
        placeholder: "Nickname",
        char_limit: 32,
        prompt: "> ",
        focused_style: @focused_style,
        blurred_style: @blurred_style
      ]
      |> TI.init()
      |> TI.focus(),
      TI.init(
        placeholder: "Email",
        char_limit: 64,
        prompt: "> ",
        focused_style: @focused_style,
        blurred_style: @blurred_style
      ),
      TI.init(
        placeholder: "Password",
        char_limit: 32,
        prompt: "> ",
        echo_mode: :password,
        echo_char: "•",
        focused_style: @focused_style,
        blurred_style: @blurred_style
      )
    ]
  end

  @impl Tela
  def init(_args) do
    inputs = make_inputs()
    focused = Enum.find(inputs, & &1.focused)
    {%{inputs: inputs, focus_index: 0, cursor_mode: :blink}, TI.blink_cmd(focused)}
  end

  @impl Tela
  def handle_event(model, %Tela.Key{key: key}) when key in [{:ctrl, "c"}, :escape] do
    {model, :quit}
  end

  def handle_event(model, %Tela.Key{key: {:ctrl, "r"}}) do
    next_mode = next_cursor_mode(model.cursor_mode)

    inputs = Enum.map(model.inputs, &TI.set_cursor_mode(&1, next_mode))

    focused = Enum.find(inputs, & &1.focused)
    cmd = if next_mode == :blink and focused != nil, do: TI.blink_cmd(focused)

    {%{model | inputs: inputs, cursor_mode: next_mode}, cmd}
  end

  def handle_event(model, %Tela.Key{key: key}) when key in [:tab, :down, :enter, :up, :shift_tab] do
    if key == :enter and model.focus_index == @field_count do
      {model, :quit}
    else
      delta = if key in [:up, :shift_tab], do: -1, else: 1
      focus_index = rem(model.focus_index + delta + @field_count + 1, @field_count + 1)

      inputs =
        model.inputs
        |> Enum.with_index()
        |> Enum.map(fn {input, i} ->
          if i == focus_index, do: TI.focus(input), else: TI.blur(input)
        end)

      focused = Enum.at(inputs, focus_index)
      cmd = if model.cursor_mode == :blink and focused != nil, do: TI.blink_cmd(focused)

      {%{model | inputs: inputs, focus_index: focus_index}, cmd}
    end
  end

  def handle_event(model, key) do
    {inputs, cmd} =
      Enum.reduce(model.inputs, {[], nil}, fn input, {acc, cmd_acc} ->
        {new_input, new_cmd} = TI.handle_event(input, key)
        {acc ++ [new_input], cmd_acc || new_cmd}
      end)

    {%{model | inputs: inputs}, cmd}
  end

  @impl Tela
  def handle_info(model, msg) do
    {inputs, cmd} =
      Enum.reduce(model.inputs, {[], nil}, fn input, {acc, cmd_acc} ->
        {new_input, new_cmd} = TI.handle_blink(input, msg)
        {acc ++ [new_input], cmd_acc || new_cmd}
      end)

    {%{model | inputs: inputs}, cmd}
  end

  @impl Tela
  def view(model) do
    button =
      if model.focus_index == @field_count do
        Style.render(@focused_style, "[ Submit ]")
      else
        "[ " <> Style.render(@blurred_style, "Submit") <> " ]"
      end

    mode_str = Atom.to_string(model.cursor_mode)

    footer =
      Tela.Frame.new(
        "\n\n" <>
          button <>
          "\n\n" <>
          Style.render(@help_style, "cursor mode is ") <>
          Style.render(@cursor_mode_help_style, mode_str) <>
          Style.render(@help_style, " (ctrl+r to change) • tab/enter: next • shift+tab: prev • ctrl+c: quit")
      )

    input_frames = Enum.map(model.inputs, &TI.view/1)
    field_frames = Enum.intersperse(input_frames, Tela.Frame.new("\n"))
    Tela.Frame.join(field_frames ++ [footer], separator: "")
  end

  defp next_cursor_mode(current) do
    idx = Enum.find_index(@cursor_modes, &(&1 == current))
    Enum.at(@cursor_modes, rem(idx + 1, length(@cursor_modes)))
  end
end

Tela.run(TextInputs)
