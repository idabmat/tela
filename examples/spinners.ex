defmodule Spinners do
  @moduledoc """
  Cycles through a collection of spinner animations.

  Demonstrates embedding a `Tela.Component.Spinner` in a parent model.
  The parent starts the initial tick cmd in `init/1`, forwards tick messages
  to `Spinner.handle_tick/2` in `handle_info/2`, and calls `Spinner.view/1`
  in `view/1`. Switching spinners replaces the spinner model and immediately
  re-arms the tick.

  Ported from the Bubbletea spinners example.

  Run with:

      mix run examples/spinners.ex

  Controls: h/← previous spinner, l/→ next spinner, q/ctrl+c/esc to quit.
  """

  use Tela

  alias Tela.Component.Spinner
  alias Tela.Style

  @presets [:line, :dot, :mini_dot, :jump, :pulse, :points, :globe, :moon, :monkey, :meter, :hamburger, :ellipsis]

  @text_style Style.foreground(Style.new(), :white)
  @help_style Style.foreground(Style.new(), :bright_black)
  @spinner_style Style.foreground(Style.new(), :cyan)

  @impl Tela
  def init(_args) do
    spinner = Spinner.init(spinner: :line, style: @spinner_style)
    {%{index: 0, spinner: spinner}, Spinner.tick_cmd(spinner)}
  end

  @impl Tela
  # Previous spinner: h or ←
  def handle_event(model, %Tela.Key{key: key}) when key in [{:char, "h"}, :left] do
    index = rem(model.index - 1 + length(@presets), length(@presets))
    spinner = Spinner.init(spinner: Enum.at(@presets, index), style: @spinner_style)
    {%{model | index: index, spinner: spinner}, Spinner.tick_cmd(spinner)}
  end

  # Next spinner: l or →
  def handle_event(model, %Tela.Key{key: key}) when key in [{:char, "l"}, :right] do
    index = rem(model.index + 1, length(@presets))
    spinner = Spinner.init(spinner: Enum.at(@presets, index), style: @spinner_style)
    {%{model | index: index, spinner: spinner}, Spinner.tick_cmd(spinner)}
  end

  # Quit
  def handle_event(model, %Tela.Key{key: key}) when key in [{:char, "q"}, {:ctrl, "c"}, :escape] do
    {model, :quit}
  end

  def handle_event(model, _key), do: {model, nil}

  @impl Tela
  def handle_info(model, msg) do
    {spinner, cmd} = Spinner.handle_tick(model.spinner, msg)
    {%{model | spinner: spinner}, cmd}
  end

  @impl Tela
  def view(model) do
    name = Enum.at(@presets, model.index)

    content =
      "\n " <>
        Spinner.view(model.spinner).content <>
        " " <>
        Style.render(@text_style, "Spinning... (#{name})") <>
        "\n\n" <>
        Style.render(@help_style, "h/l, ←/→: change spinner • q: exit")

    Tela.Frame.new(content)
  end
end

Tela.run(Spinners)
