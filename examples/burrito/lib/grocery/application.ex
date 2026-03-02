defmodule Grocery.Application do
  use Application

  @impl true
  def start(_type, _args) do
    {:ok, _pid} = Grocery.CLI.run()
    System.halt(0)
  end
end
