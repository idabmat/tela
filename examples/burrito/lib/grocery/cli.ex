defmodule Grocery.CLI do
  @moduledoc false
  use Tela

  @impl Tela
  def init(_args) do
    {%{
       cursor: 0,
       choices: ["Buy carrots", "Buy celery", "Buy kohlrabi"],
       selected: MapSet.new()
     }, nil}
  end

  @impl Tela
  def handle_event(model, %Tela.Key{key: key}) when key in [:up, {:char, "k"}] do
    {%{model | cursor: max(0, model.cursor - 1)}, nil}
  end

  def handle_event(model, %Tela.Key{key: key}) when key in [:down, {:char, "j"}] do
    {%{model | cursor: min(length(model.choices) - 1, model.cursor + 1)}, nil}
  end

  def handle_event(model, %Tela.Key{key: key}) when key in [:enter, {:char, " "}] do
    selected =
      if MapSet.member?(model.selected, model.cursor),
        do: MapSet.delete(model.selected, model.cursor),
        else: MapSet.put(model.selected, model.cursor)

    {%{model | selected: selected}, nil}
  end

  def handle_event(model, %Tela.Key{key: key}) when key in [{:char, "q"}, {:ctrl, "c"}] do
    {model, :quit}
  end

  def handle_event(model, _key), do: {model, nil}

  @impl Tela
  def handle_info(model, _msg), do: {model, nil}

  @impl Tela
  def view(model) do
    rows =
      model.choices
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {choice, i} ->
        cursor = if model.cursor == i, do: ">", else: " "
        checked = if MapSet.member?(model.selected, i), do: "x", else: " "
        "#{cursor} [#{checked}] #{choice}"
      end)

    Tela.Frame.new("What should we buy at the market?\n\n#{rows}\n\nPress j/k to move, space to select, q to quit.")
  end
end
