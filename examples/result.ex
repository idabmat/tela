defmodule Result do
  @moduledoc """
  A single-choice picker that returns a value to the caller after exiting.

  Demonstrates how to retrieve a result from a Tela program using the
  `{:ok, final_model}` return value of `Tela.run/2`. The chosen item is
  stored in the model and read by the caller after the runtime exits.
  Ported from the Bubbletea result example.

  Run with:

      mix run examples/result.ex

  Controls: j/↓ move down, k/↑ move up, enter to choose, q/ctrl+c/esc to quit.
  """

  use Tela

  @choices ["Taro", "Coffee", "Lychee"]

  @impl Tela
  def init(_args) do
    {%{cursor: 0, choice: ""}, nil}
  end

  @impl Tela
  # Confirm selection — store the choice and quit.
  def handle_event(model, %Tela.Key{key: :enter}) do
    choice = Enum.at(@choices, model.cursor)
    {%{model | choice: choice}, :quit}
  end

  # Move cursor down (wraps around).
  def handle_event(model, %Tela.Key{key: key}) when key in [:down, {:char, "j"}] do
    {%{model | cursor: rem(model.cursor + 1, length(@choices))}, nil}
  end

  # Move cursor up (wraps around).
  def handle_event(model, %Tela.Key{key: key}) when key in [:up, {:char, "k"}] do
    {%{model | cursor: rem(model.cursor - 1 + length(@choices), length(@choices))}, nil}
  end

  # Quit without selection.
  def handle_event(model, %Tela.Key{key: key}) when key in [{:char, "q"}, {:ctrl, "c"}, :escape] do
    {model, :quit}
  end

  def handle_event(model, _key), do: {model, nil}

  @impl Tela
  def handle_info(model, _msg), do: {model, nil}

  @impl Tela
  def view(model) do
    rows =
      @choices
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {choice, i} ->
        marker = if model.cursor == i, do: "(•)", else: "( )"
        "#{marker} #{choice}"
      end)

    Tela.Frame.new("What kind of Bubble Tea would you like to order?\n\n#{rows}\n\nPress enter to choose, q to quit.")
  end
end

{:ok, model} = Tela.run(Result)

if model.choice != "" do
  IO.puts("\nYou chose: #{model.choice}")
end
