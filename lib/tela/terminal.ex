defmodule Tela.Terminal do
  @moduledoc """
  OTP 28 terminal I/O wrappers.

  Encapsulates all side-effectful interactions with the OS terminal:
  raw/cooked mode switching, alternate screen buffer, reading raw bytes
  from stdin, and writing iodata to stdout.

  All functions in this module have side effects and are deliberately not
  unit-tested. See `Tela.Input` for the pure key-parsing logic and
  `Tela.Renderer` for the pure diff/render logic.

  ## OTP 28 requirement

  Raw mode is enabled via `:shell.start_interactive/1`, which was introduced
  in OTP 28. Calling any function in this module on an older OTP version will
  raise `UndefinedFunctionError`.
  """

  @doc """
  Enters raw terminal mode.

  In raw mode, keystrokes are delivered immediately without line buffering
  or echo. Returns `:ok` on success, or `{:error, reason}` if the terminal
  cannot be switched to raw mode — for example, when the VM is already in
  interactive mode or stdin is not a TTY.
  """
  @spec enter_raw_mode() :: :ok | {:error, term()}
  def enter_raw_mode do
    :shell.start_interactive({:noshell, :raw})
  end

  @doc """
  Restores the terminal to cooked (line-buffered) mode.

  Safe to call even if raw mode was never successfully entered — OTP handles
  the no-op gracefully.
  """
  @spec exit_raw_mode() :: :ok | {:error, :already_started}
  def exit_raw_mode do
    :shell.start_interactive({:noshell, :cooked})
  end

  @doc """
  Switches the terminal to the alternate screen buffer.

  The alternate screen buffer is a separate display area that preserves the
  user's terminal scrollback. Always pair with `exit_alternate_screen/0`.
  """
  @spec enter_alternate_screen() :: :ok
  def enter_alternate_screen do
    :io.put_chars(:user, "\e[?1049h")
  end

  @doc """
  Exits the alternate screen buffer and restores the user's previous terminal
  contents.
  """
  @spec exit_alternate_screen() :: :ok
  def exit_alternate_screen do
    :io.put_chars(:user, "\e[?1049l")
  end

  @doc """
  Clears the entire screen and moves the cursor to the top-left.

  Used during teardown to ensure a clean state before exiting the alternate
  screen buffer.
  """
  @spec clear() :: :ok
  def clear do
    :io.put_chars(:user, "\e[2J\e[H")
  end

  @doc """
  Hides the terminal cursor.

  Call on startup to avoid cursor flicker during renders. Always pair with
  `show_cursor/0`.
  """
  @spec hide_cursor() :: :ok
  def hide_cursor do
    :io.put_chars(:user, "\e[?25l")
  end

  @doc """
  Shows the terminal cursor.
  """
  @spec show_cursor() :: :ok
  def show_cursor do
    :io.put_chars(:user, "\e[?25h")
  end

  @doc """
  Moves the terminal cursor to the given 1-indexed row and column.

  Used by the runtime after each render to position the real terminal cursor
  at the location specified by `Tela.Frame.cursor`. The caller is responsible
  for converting 0-indexed frame coordinates to 1-indexed ANSI coordinates
  before calling this function.
  """
  @spec move_cursor(row :: pos_integer(), col :: pos_integer()) :: :ok
  def move_cursor(row, col) when is_integer(row) and row >= 1 and is_integer(col) and col >= 1 do
    :io.put_chars(:user, "\e[#{row};#{col}H")
  end

  @doc """
  Sets the terminal cursor shape.

  Accepted shapes:
  - `:block` — steady block cursor (`\e[2 q`)
  - `:bar` — steady bar cursor (`\e[6 q`)
  - `:underline` — steady underline cursor (`\e[4 q`)

  Steady (non-blinking) variants are used; the terminal's own blink preference
  applies. Used by the runtime when a `Tela.Frame` carries a non-nil `cursor`
  field.
  """
  @spec set_cursor_shape(shape :: :block | :bar | :underline) :: :ok
  def set_cursor_shape(:block), do: :io.put_chars(:user, "\e[2 q")
  def set_cursor_shape(:bar), do: :io.put_chars(:user, "\e[6 q")
  def set_cursor_shape(:underline), do: :io.put_chars(:user, "\e[4 q")

  @doc """
  Reads up to 1024 raw bytes from stdin, blocking until at least one byte is
  available.

  Returns a binary on success, or `:eof` when stdin is closed. Multiple
  keystrokes may be batched into a single call, especially during paste. Use
  `Tela.Input.parse/1` to decode the result into a list of `Tela.Key.t()`
  structs.
  """
  # :io.get_chars/2 returns :eof when stdin closes, but the OTP typespec does
  # not include this case. The broader return type is declared here so that
  # callers (e.g. Tela.Runtime.reader_loop/1) can pattern match on :eof without
  # triggering a Dialyzer pattern_match warning.
  @spec read() :: binary() | :eof
  def read do
    :io.get_chars(~c"", 1024)
  end

  @doc """
  Writes iodata to the terminal (stdout via `:user`).
  """
  @spec write(iodata()) :: :ok
  def write(iodata) do
    :io.put_chars(:user, iodata)
  end

  @doc """
  Returns the current terminal dimensions as `{cols, rows}`.

  Returns `{80, 24}` as a safe fallback if the terminal does not support
  dimension queries.
  """
  @spec dimensions() :: {cols :: pos_integer(), rows :: pos_integer()}
  def dimensions do
    cols =
      case :io.columns() do
        {:ok, c} -> c
        _ -> 80
      end

    rows =
      case :io.rows() do
        {:ok, r} -> r
        _ -> 24
      end

    {cols, rows}
  end
end
