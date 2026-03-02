defmodule Tela.Renderer do
  @moduledoc """
  Produces minimal ANSI output to update the terminal from one frame to the next.

  The renderer compares the previous frame's lines against the next frame's lines
  and emits ANSI escape sequences only for lines that have changed. This avoids
  full-screen redraws on every update, preventing flicker.

  ## Usage

      prev = ["Hello", "World"]
      next = ["Hello", "Tela"]

      iodata = Tela.Renderer.diff(prev, next)
      :io.put_chars(:user, iodata)

  On the first render, pass an empty list as `prev` to clear the screen and
  write all lines.

      iodata = Tela.Renderer.diff([], ["Hello", "Tela"])

  ## Cursor parking

  After every render the cursor is moved to the row immediately below the last
  line of the frame. This keeps the cursor out of the visible UI area.

  ## ANSI sequences used

  | Sequence | Meaning |
  |---|---|
  | `\\e[2J` | Clear entire screen |
  | `\\e[H` | Move cursor to top-left (home) |
  | `\\e[R;CH` | Move cursor to row R, column C |
  | `\\e[K` | Clear from cursor to end of line |

  """

  @doc """
  Produces iodata to update the terminal from `prev_lines` to `next_lines`.

  Compares each line by index. For lines that differ, emits a cursor-move
  sequence followed by the new content and an end-of-line clear. Lines that
  are identical produce no output.

  When `prev_lines` is empty, performs a full clear (`\\e[2J\\e[H`) before
  writing all lines.

  After writing, the cursor is parked one row below the last line.

  ## Examples

      iex> Tela.Renderer.diff([], ["Hello"]) |> IO.iodata_to_binary()
      "\\e[2J\\e[H\\e[1;1HHello\\e[K\\e[2;1H"

      iex> Tela.Renderer.diff(["Hello"], ["Hello"]) |> IO.iodata_to_binary()
      ""

  """
  @spec diff(prev_lines :: [String.t()], next_lines :: [String.t()]) :: iodata()
  def diff([], next_lines) do
    line_output =
      next_lines
      |> Enum.with_index(1)
      |> Enum.map(fn {line, row} -> ["\e[#{row};1H", line, "\e[K"] end)

    park_row = length(next_lines) + 1
    ["\e[2J", "\e[H", line_output, "\e[#{park_row};1H"]
  end

  def diff(prev_lines, next_lines) do
    max_rows = max(length(prev_lines), length(next_lines))

    changed_output =
      Enum.map(0..(max_rows - 1)//1, fn index ->
        row = index + 1
        prev = Enum.at(prev_lines, index)
        next = Enum.at(next_lines, index)

        cond do
          # Line exists in next and has changed (or is new)
          not is_nil(next) and next != prev ->
            ["\e[#{row};1H", next, "\e[K"]

          # Line existed in prev but is gone in next — clear it
          is_nil(next) and not is_nil(prev) ->
            ["\e[#{row};1H", "\e[K"]

          # Unchanged
          true ->
            []
        end
      end)

    park_row = length(next_lines) + 1

    case IO.iodata_to_binary(changed_output) do
      "" -> ""
      _ -> [changed_output, "\e[#{park_row};1H"]
    end
  end
end
