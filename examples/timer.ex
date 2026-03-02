defmodule Timer do
  @moduledoc """
  A countdown timer that starts from 5 seconds and quits automatically on
  timeout. The timer can be paused, resumed, and reset while running.

  Remaining time is tracked in milliseconds and displayed as MM:SS.mmm.
  Ticking pauses when the timer is stopped and resumes on the next start,
  so no wasted tasks are spawned while paused.

  Ported from the Bubbletea timer example.

  Run with:

      mix run examples/timer.ex

  Controls: s start/stop, r reset, q/ctrl+c quit.
  """

  use Tela

  alias Tela.Style

  @duration_ms 5_000
  @tick_ms 1

  @time_style Style.foreground(Style.new(), :cyan)
  @label_style Style.foreground(Style.new(), :white)
  @help_style Style.foreground(Style.new(), :bright_black)

  @impl Tela
  def init(_args) do
    model = %{remaining_ms: @duration_ms, running: true, timed_out: false}
    {model, tick_cmd()}
  end

  @impl Tela
  # Toggle start/stop.
  def handle_event(model, %Tela.Key{key: {:char, "s"}}) do
    running = !model.running
    cmd = if running, do: tick_cmd()
    {%{model | running: running}, cmd}
  end

  # Reset to the full duration; re-arm tick if currently running.
  def handle_event(model, %Tela.Key{key: {:char, "r"}}) do
    cmd = if model.running, do: tick_cmd()
    {%{model | remaining_ms: @duration_ms, timed_out: false}, cmd}
  end

  # Quit.
  def handle_event(model, %Tela.Key{key: key}) when key in [{:char, "q"}, {:ctrl, "c"}] do
    {model, :quit}
  end

  def handle_event(model, _key), do: {model, nil}

  @impl Tela
  # Tick: decrement remaining time; quit on timeout.
  def handle_info(model, :tick) when model.running and model.remaining_ms > 0 do
    remaining = model.remaining_ms - @tick_ms

    if remaining <= 0 do
      {%{model | remaining_ms: 0, timed_out: true}, :quit}
    else
      {%{model | remaining_ms: remaining}, tick_cmd()}
    end
  end

  def handle_info(model, _msg), do: {model, nil}

  @impl Tela
  def view(model) do
    content =
      if model.timed_out do
        "All done!\n"
      else
        remaining = Style.render(@time_style, format_duration(model.remaining_ms))
        label = Style.render(@label_style, "Exiting in ")
        status = if model.running, do: "stop", else: "start"

        label <>
          remaining <>
          "\n\n" <>
          Style.render(@help_style, "s #{status} • r reset • q quit")
      end

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

Tela.run(Timer)
