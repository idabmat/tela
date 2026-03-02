defmodule Stopwatch do
  @moduledoc """
  A running stopwatch with start/stop and reset controls.

  Elapsed time is tracked in milliseconds and displayed as MM:SS.mmm.
  Ticking pauses when the stopwatch is stopped and resumes on the next
  start, so no wasted tasks are spawned while paused.

  Ported from the Bubbletea stopwatch example.

  Run with:

      mix run examples/stopwatch.ex

  Controls: s start/stop, r reset, q/ctrl+c quit.
  """

  use Tela

  alias Tela.Style

  @tick_ms 1

  @time_style Style.foreground(Style.new(), :cyan)
  @label_style Style.foreground(Style.new(), :white)
  @help_style Style.foreground(Style.new(), :bright_black)

  @impl Tela
  def init(_args) do
    {%{running: true, elapsed_ms: 0}, tick_cmd()}
  end

  @impl Tela
  # Toggle start/stop.
  def handle_event(model, %Tela.Key{key: {:char, "s"}}) do
    running = !model.running
    cmd = if running, do: tick_cmd()
    {%{model | running: running}, cmd}
  end

  # Reset elapsed time; re-arm tick if currently running.
  def handle_event(model, %Tela.Key{key: {:char, "r"}}) do
    cmd = if model.running, do: tick_cmd()
    {%{model | elapsed_ms: 0}, cmd}
  end

  # Quit.
  def handle_event(model, %Tela.Key{key: key}) when key in [{:char, "q"}, {:ctrl, "c"}] do
    {model, :quit}
  end

  def handle_event(model, _key), do: {model, nil}

  @impl Tela
  # Advance elapsed time by one tick and re-arm.
  def handle_info(model, :tick) when model.running do
    {%{model | elapsed_ms: model.elapsed_ms + @tick_ms}, tick_cmd()}
  end

  def handle_info(model, _msg), do: {model, nil}

  @impl Tela
  def view(model) do
    elapsed = Style.render(@time_style, format_duration(model.elapsed_ms))
    label = Style.render(@label_style, "Elapsed: ")
    status = if model.running, do: "stop", else: "start"

    content =
      label <>
        elapsed <>
        "\n\n" <>
        Style.render(@help_style, "s #{status} • r reset • q quit")

    Tela.Frame.new(content)
  end

  defp tick_cmd do
    {:task,
     fn ->
       Process.sleep(@tick_ms)
       :tick
     end}
  end

  defp format_duration(ms) do
    total_s = div(ms, 1000)
    mm = total_s |> div(60) |> Integer.to_string() |> String.pad_leading(2, "0")
    ss = total_s |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")
    mmm = ms |> rem(1000) |> Integer.to_string() |> String.pad_leading(3, "0")
    "#{mm}:#{ss}.#{mmm}"
  end
end

Tela.run(Stopwatch)
