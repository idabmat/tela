defmodule Debounce do
  @moduledoc """
  Demonstrates debouncing key events.

  Every keypress increments a counter and re-arms a 1-second debounce task.
  The task carries the counter value at the time it was armed. When it fires,
  `handle_info/2` checks whether the value still matches the model — if it
  does, no further keypresses have arrived and the app quits. If not, a newer
  task is already in flight and this one is silently discarded.

  Ported from the Bubbletea debounce example.

  Run with:

      mix run examples/debounce.ex

  Press any key, then wait 1 second without pressing anything to exit.
  """

  use Tela

  alias Tela.Style

  @debounce_ms 1_000

  @count_style Style.foreground(Style.new(), :cyan)
  @help_style Style.foreground(Style.new(), :bright_black)

  @impl Tela
  def init(_args) do
    {%{tag: 0, presses: 0}, nil}
  end

  @impl Tela
  def handle_event(model, _key) do
    tag = model.tag + 1
    {%{model | tag: tag, presses: model.presses + 1}, debounce_cmd(tag)}
  end

  @impl Tela
  def handle_info(model, {:debounce, tag}) when tag == model.tag do
    {model, :quit}
  end

  def handle_info(model, _msg), do: {model, nil}

  @impl Tela
  def view(model) do
    content =
      Style.render(@count_style, "Key presses: #{model.presses}") <>
        "\n\n" <>
        Style.render(@help_style, "Press any key, then wait 1 second without pressing anything to exit.")

    Tela.Frame.new(content)
  end

  defp debounce_cmd(tag) do
    {:task,
     fn ->
       Process.sleep(@debounce_ms)
       {:debounce, tag}
     end}
  end
end

Tela.run(Debounce)
