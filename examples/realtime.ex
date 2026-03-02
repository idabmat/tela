defmodule Realtime.Producer do
  @moduledoc false

  @doc """
  Spawns a producer process that sends `:event` to `runtime_pid` at random
  intervals between 100 and 1000 milliseconds.

  The producer is a plain Elixir process — no Tela involvement. In a real
  application it would be started from a supervision tree and given the
  runtime pid through configuration or a registry.
  """
  @spec start(pid()) :: pid()
  def start(runtime_pid) do
    spawn(fn -> loop(runtime_pid) end)
  end

  defp loop(runtime_pid) do
    Process.sleep(Enum.random(100..1000))
    send(runtime_pid, :event)
    loop(runtime_pid)
  end
end

defmodule Realtime do
  @moduledoc """
  Displays a live count of events received from an external process.

  Demonstrates how an independent process can drive a Tela application in
  real time by sending messages directly to the runtime pid. The producer
  (`Realtime.Producer`) is started before `Tela.run/2` using `self()` —
  which is the runtime pid, because `Tela.run/2` runs the loop in the
  calling process. `init/1` stays pure: it does not start any processes.

  Ported from the Bubbletea realtime example.

  Run with:

      mix run examples/realtime.ex

  Press any key to exit.
  """

  use Tela

  alias Tela.Component.Spinner
  alias Tela.Style

  @text_style Style.foreground(Style.new(), :white)
  @help_style Style.foreground(Style.new(), :bright_black)
  @spinner_style Style.foreground(Style.new(), :cyan)

  @impl Tela
  def init(_args) do
    spinner = Spinner.init(spinner: :dot, style: @spinner_style)
    {%{responses: 0, spinner: spinner}, Spinner.tick_cmd(spinner)}
  end

  @impl Tela
  def handle_event(model, _key), do: {model, :quit}

  @impl Tela
  # External event from Realtime.Producer — increment the counter.
  def handle_info(model, :event) do
    {%{model | responses: model.responses + 1}, nil}
  end

  def handle_info(model, msg) do
    {spinner, cmd} = Spinner.handle_tick(model.spinner, msg)
    {%{model | spinner: spinner}, cmd}
  end

  @impl Tela
  def view(model) do
    content =
      "\n " <>
        Spinner.view(model.spinner).content <>
        Style.render(@text_style, "Events received: #{model.responses}") <>
        "\n\n" <>
        Style.render(@help_style, "Press any key to exit")

    Tela.Frame.new(content)
  end
end

# self() here is the runtime pid — Tela.run/2 blocks in the calling process.
# Starting the producer before Tela.run/2 means it begins sending :event
# messages immediately; they queue in the mailbox until the receive loop is
# ready. init/1 never needs to know about the producer.
runtime_pid = self()
Realtime.Producer.start(runtime_pid)
Tela.run(Realtime)
