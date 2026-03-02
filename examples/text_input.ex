defmodule TextInput do
  @moduledoc """
  A simple text input field.

  Demonstrates the `Tela.Component.TextInput` component with a single focused
  field, a placeholder, and a character limit.

  Ported from the Bubbletea textinput example.

  Run with:

      mix run examples/text_input.ex

  Controls: enter/esc/ctrl+c to quit.
  """

  use Tela

  alias Tela.Component.TextInput, as: TI

  @impl Tela
  def init(_args) do
    input =
      [placeholder: "Pikachu", char_limit: 156]
      |> TI.init()
      |> TI.focus()

    {%{input: input}, TI.blink_cmd(input)}
  end

  @impl Tela
  def handle_event(model, %Tela.Key{key: key}) when key in [:enter, :escape, {:ctrl, "c"}] do
    {model, :quit}
  end

  def handle_event(model, key) do
    {input, cmd} = TI.handle_event(model.input, key)
    {%{model | input: input}, cmd}
  end

  @impl Tela
  def handle_info(model, {:text_input_blink, _id} = msg) do
    {input, cmd} = TI.handle_blink(model.input, msg)
    {%{model | input: input}, cmd}
  end

  def handle_info(model, _msg), do: {model, nil}

  @impl Tela
  def view(model) do
    Tela.Frame.join(
      [
        Tela.Frame.new("What's your favorite Pokémon?\n\n"),
        TI.view(model.input),
        Tela.Frame.new("\n\n(esc to quit)")
      ],
      separator: ""
    )
  end
end

Tela.run(TextInput)
