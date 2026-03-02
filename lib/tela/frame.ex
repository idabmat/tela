defmodule Tela.Frame do
  @moduledoc """
  A rendered frame returned by `c:Tela.view/1` and `c:Tela.Component.view/1`.

  A `Frame` carries two pieces of information: the rendered UI content as a
  plain string, and an optional cursor position that tells the runtime where
  to place the real terminal cursor after rendering.

  ## Content

  `content` is the full UI string for this frame, with lines separated by
  `\\n`. It is passed directly to `Tela.Renderer.diff/2` for line-diff
  rendering, exactly as the `String.t()` return from `view/1` was previously.

  ## Cursor

  `cursor` is either `nil` (hide the terminal cursor) or a
  `{row, col, shape}` tuple:

  - `row` — 0-indexed row relative to this frame's top-left.
  - `col` — 0-indexed column relative to this frame's top-left.
  - `shape` — `:block`, `:bar`, or `:underline`.

  Cursor coordinates are **relative to the component's own top-left**. When
  frames are composed with `join/2`, the accumulated row offset of each
  preceding frame is added to the cursor row of the frame that holds it.

  ## Composition

  Use `join/2` to stack frames vertically. It concatenates content strings
  with a separator (default `"\\n"`), adjusts the cursor row of each frame by
  the cumulative line count of all preceding frames and their separators, and
  takes the cursor from the first frame in the list that has a non-nil cursor.

      a = Frame.new("Line A")
      b = Frame.new("Line B", cursor: {0, 3, :block})
      Frame.join([a, b])
      # => %Frame{content: "Line A\\nLine B", cursor: {1, 3, :block}}

  ## Usage in `view/1`

  A top-level app with no interactive cursor:

      def view(model) do
        Frame.new("Count: \#{model.count}\\nPress q to quit.")
      end

  A top-level app composing a `TextInput` component:

      def view(model) do
        header = Frame.new("What's your name?\\n")
        input  = TextInput.view(model.input)
        footer = Frame.new("\\n(esc to quit)")
        Frame.join([header, input, footer], separator: "")
      end
  """

  @typedoc "The shape of the terminal cursor."
  @type cursor_shape :: :block | :bar | :underline

  @typedoc """
  A cursor position within a frame. Coordinates are 0-indexed and relative
  to the frame's own top-left corner.
  """
  @type cursor :: {row :: non_neg_integer(), col :: non_neg_integer(), shape :: cursor_shape()}

  @typedoc "A rendered frame, optionally carrying a cursor position."
  @type t :: %__MODULE__{
          content: String.t(),
          cursor: cursor() | nil
        }

  defstruct content: "", cursor: nil

  @doc """
  Returns a new frame with the given content and no cursor.

  The terminal cursor will be hidden while this frame is displayed.
  """
  @spec new(content :: String.t()) :: t()
  def new(content) when is_binary(content) do
    %__MODULE__{content: content, cursor: nil}
  end

  @doc """
  Returns a new frame with the given content and cursor options.

  ## Options

  - `cursor:` — `{row, col, shape}` tuple or `nil`. Coordinates are 0-indexed
    and relative to this frame's top-left. Shape is `:block`, `:bar`, or
    `:underline`. `nil` hides the cursor (equivalent to `new/1`).
  """
  @spec new(content :: String.t(), cursor: cursor() | nil) :: t()
  def new(content, opts) when is_binary(content) and is_list(opts) do
    %__MODULE__{content: content, cursor: Keyword.get(opts, :cursor, nil)}
  end

  @doc """
  Stacks a list of frames vertically, producing a single composed frame.

  Content strings are joined with `separator` (default `"\\n"`). The cursor
  is taken from the **first frame in the list that has a non-nil cursor**,
  with its row adjusted by the cumulative line count of all preceding frames
  and their separators.

  ## Options

  - `separator:` — the string inserted between each frame's content
    (default `"\\n"`).

  ## Examples

      iex> alias Tela.Frame
      iex> a = Frame.new("Line A")
      iex> b = Frame.new("Line B", cursor: {0, 2, :block})
      iex> Frame.join([a, b])
      %Frame{content: "Line A\\nLine B", cursor: {1, 2, :block}}

      iex> alias Tela.Frame
      iex> frames = [Frame.new("A"), Frame.new("B"), Frame.new("C")]
      iex> Frame.join(frames)
      %Frame{content: "A\\nB\\nC", cursor: nil}
  """
  @spec join([t()], separator: String.t()) :: t()
  def join(frames, opts \\ []) when is_list(frames) do
    separator = Keyword.get(opts, :separator, "\n")
    sep_newlines = newline_count(separator)

    {content, cursor, _offset} =
      Enum.reduce(frames, {"", nil, 0}, fn frame, {acc_content, acc_cursor, row_offset} ->
        new_content =
          if acc_content == "" do
            frame.content
          else
            acc_content <> separator <> frame.content
          end

        new_cursor =
          if acc_cursor == nil do
            case frame.cursor do
              nil -> nil
              {row, col, shape} -> {row + row_offset, col, shape}
            end
          else
            acc_cursor
          end

        next_offset = row_offset + newline_count(frame.content) + sep_newlines

        {new_content, new_cursor, next_offset}
      end)

    %__MODULE__{content: content, cursor: cursor}
  end

  # Returns the number of newline characters in a string.
  defp newline_count(str) do
    str |> String.graphemes() |> Enum.count(&(&1 == "\n"))
  end
end
