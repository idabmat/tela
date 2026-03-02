defmodule Tela.Runtime do
  @moduledoc """
  The Tela run loop.

  `Runtime` owns the full lifecycle of a Tela application:

  1. Sets up the terminal (raw mode, alternate screen, hidden cursor).
  2. Calls the module's `init/1` callback to obtain the initial model and an optional startup cmd.
  3. Renders the initial frame via `view/1` and `Tela.Renderer`.
  4. Spawns a dedicated **reader process** that blocks on
     `Tela.Terminal.read/0` and forwards raw bytes as `{:input, binary}`
     messages.
  5. Enters a `receive` loop, dispatching messages to `handle_event/2` or
     `handle_info/2`, re-rendering after every state change.
  6. Guarantees terminal cleanup via `try/after` regardless of whether the
     program exits cleanly, raises, or receives an exit signal.

  ## Message protocol

  | Message | Source | Dispatched to |
  |---|---|---|
  | `{:input, binary}` | Reader process | `handle_event/2` (once per parsed key) |
  | `{:task_result, term()}` | Spawned task | `handle_info/2` |
  | Any other message | External senders | `handle_info/2` |

  ## Cmd handling

  After every callback invocation, the returned `cmd` is executed:

  - `nil` — nothing happens.
  - `:quit` — the run loop exits and the terminal is restored.
  - `{:task, fun}` — `fun` is spawned in a new process. When it returns,
    the result is wrapped as `{:task_result, result}` and sent back to the
    runtime process, which delivers it to `handle_info/2`.

  ## Usage

  Do not call this module directly. Use `Tela.run/2` instead.
  """

  alias Tela.Input
  alias Tela.Renderer
  alias Tela.Terminal

  @doc """
  Starts the runtime for the given module with the given args.

  Calls `module.init(args)` to obtain the initial model and startup cmd,
  then enters the run loop. Blocks until the application quits and returns
  `{:ok, final_model}`.

  `module` must implement the `Tela` behaviour (i.e. define `init/1`,
  `handle_event/2`, `handle_info/2`, and `view/1`).
  """
  @spec run(module :: module(), args :: term()) :: {:ok, term()}
  def run(module, args) do
    setup_terminal()

    final_model =
      try do
        {model, init_cmd} = module.init(args)
        prev_lines = render(module, model, [])

        case init_cmd do
          :quit ->
            model

          _ ->
            dispatch_cmd(init_cmd, self())
            loop(module, model, prev_lines)
        end
      after
        teardown_terminal()
      end

    {:ok, final_model}
  end

  @dialyzer {:no_match, setup_terminal: 0}
  defp setup_terminal do
    case Terminal.enter_raw_mode() do
      :ok -> :ok
      {:error, :already_started} -> :ok
      {:error, reason} -> raise "Tela could not enter raw terminal mode: #{inspect(reason)}"
    end

    Terminal.enter_alternate_screen()
    Terminal.hide_cursor()
  end

  defp teardown_terminal do
    Terminal.show_cursor()
    Terminal.clear()
    Terminal.exit_alternate_screen()
    Terminal.exit_raw_mode()
  end

  # Renders the current model. Returns the list of lines (for diffing next
  # frame). Writes iodata to the terminal only when there is something to write.
  # After writing, positions the real terminal cursor if the frame specifies one.
  defp render(module, model, prev_lines) do
    %Tela.Frame{content: content, cursor: cursor} = module.view(model)
    next_lines = String.split(content, "\n")
    iodata = Renderer.diff(prev_lines, next_lines)

    case IO.iodata_to_binary(iodata) do
      "" -> :ok
      _ -> Terminal.write(iodata)
    end

    position_cursor(cursor)

    next_lines
  end

  # Shows and positions the real terminal cursor when the frame specifies one,
  # hides it otherwise.
  defp position_cursor(nil) do
    Terminal.hide_cursor()
  end

  defp position_cursor({row, col, shape}) do
    # Frame coordinates are 0-indexed; ANSI sequences are 1-indexed.
    Terminal.set_cursor_shape(shape)
    Terminal.move_cursor(row + 1, col + 1)
    Terminal.show_cursor()
  end

  @doc false
  # Processes a batch of parsed keys against the module's handle_event/2
  # callback, short-circuiting on the first :quit cmd.
  #
  # No side effects — pure data transformation. Returns
  # {:quit | :cont, new_model, cmds} where cmds is the list of cmd values
  # returned by handle_event/2 for each key processed (in order). Cmds from
  # keys after a :quit are not included.
  #
  # Dispatching cmds and rendering are the caller's responsibility.
  # Made public (with @doc false) so it can be unit-tested directly.
  def process_keys(module, keys, model) do
    result =
      Enum.reduce_while(keys, {model, []}, fn key, {m, cmds} ->
        {m2, cmd} = module.handle_event(m, key)

        case cmd do
          :quit -> {:halt, {:quit, m2, Enum.reverse(cmds)}}
          _ -> {:cont, {m2, [cmd | cmds]}}
        end
      end)

    case result do
      {:quit, m, cmds} -> {:quit, m, cmds}
      {m, cmds} -> {:cont, m, Enum.reverse(cmds)}
    end
  end

  defp loop(module, model, prev_lines) do
    runtime_pid = self()
    start_reader(runtime_pid)

    do_loop(module, model, prev_lines)
  end

  # Spawns a reader process that blocks on Terminal.read/0 and sends
  # {:input, binary} to the runtime process for each chunk of raw bytes.
  defp start_reader(runtime_pid) do
    spawn(fn -> reader_loop(runtime_pid) end)
  end

  defp reader_loop(runtime_pid) do
    case Terminal.read() do
      :eof ->
        send(runtime_pid, {:input, :eof})

      data when is_binary(data) or is_list(data) ->
        send(runtime_pid, {:input, IO.iodata_to_binary(data)})
        reader_loop(runtime_pid)

      _ ->
        reader_loop(runtime_pid)
    end
  end

  defp do_loop(module, model, prev_lines) do
    receive do
      {:input, :eof} ->
        model

      {:input, raw} ->
        keys = Input.parse(raw)

        case process_keys(module, keys, model) do
          {:quit, new_model, cmds} ->
            Enum.each(cmds, &dispatch_cmd(&1, self()))
            new_model

          {:cont, new_model, cmds} ->
            Enum.each(cmds, &dispatch_cmd(&1, self()))
            new_prev = render(module, new_model, prev_lines)
            do_loop(module, new_model, new_prev)
        end

      {:task_result, result} ->
        {new_model, cmd} = module.handle_info(model, result)
        new_prev = render(module, new_model, prev_lines)

        case cmd do
          :quit ->
            new_model

          _ ->
            dispatch_cmd(cmd, self())
            do_loop(module, new_model, new_prev)
        end

      msg ->
        {new_model, cmd} = module.handle_info(model, msg)
        new_prev = render(module, new_model, prev_lines)

        case cmd do
          :quit ->
            new_model

          _ ->
            dispatch_cmd(cmd, self())
            do_loop(module, new_model, new_prev)
        end
    end
  end

  # Executes a nil or {:task, fun} cmd. :quit is never included in the cmds
  # list — it is stripped by process_keys/3 and handled separately by callers
  # via the {:quit, ...} tag. Always returns :cont.
  defp dispatch_cmd(nil, _runtime_pid), do: :cont

  defp dispatch_cmd({:task, fun}, runtime_pid) do
    spawn(fn ->
      result = fun.()
      send(runtime_pid, {:task_result, result})
    end)

    :cont
  end
end
