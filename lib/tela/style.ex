defmodule Tela.Style do
  @moduledoc """
  Composable ANSI text styles for terminal UIs.

  `Tela.Style` provides a pure, pipe-friendly API for building and applying
  ANSI styling to strings. Styles are represented as plain structs — no
  processes, no I/O — and applied via `render/2`.

  ## Usage

      iex> Tela.Style.new() |> Tela.Style.bold() |> Tela.Style.foreground(:cyan) |> Tela.Style.render("hello")
      "\e[1m\e[36mhello\e[0m"

  Styles are reusable and composable:

      base  = Tela.Style.new() |> Tela.Style.bold()
      error = base |> Tela.Style.foreground(:red)
      info  = base |> Tela.Style.foreground(:cyan)

      Tela.Style.render(error, "Something went wrong")
      Tela.Style.render(info, "All good")

  ## Colours

  Named colour atoms map to standard ANSI palette slots. The actual colour
  displayed depends on the terminal's colour scheme — Tela does not hardcode
  RGB values. This means styled Tela apps automatically respect the user's
  terminal theme.

  Available colours: `:black`, `:red`, `:green`, `:yellow`, `:blue`,
  `:magenta`, `:cyan`, `:white`, `:bright_black`, `:bright_red`,
  `:bright_green`, `:bright_yellow`, `:bright_blue`, `:bright_magenta`,
  `:bright_cyan`, `:bright_white`, `:default`.

  ## Reverse video

  `reverse/1` swaps the terminal's foreground and background colours (`\\e[7m`).
  This is the standard way to render a cursor block — the result automatically
  adapts to the user's terminal colour scheme.

  ## Borders

  Border styles: `:none`, `:single`, `:double`, `:rounded`, `:thick`.

  ## Multi-line strings

  `render/2` supports multi-line strings (containing `\\n`). Lines are
  normalised to equal width before padding and borders are applied, ensuring
  rectangular output. Attributes and colours are applied per-line with a
  `\\e[0m` reset at the end of each line to prevent colour bleeding.

  ## Measuring visible width

  Use `width/1` to measure the visible width of a string, stripping any ANSI
  escape codes before counting. Useful for layout calculations in `view/1`.
  """

  @typedoc """
  A named terminal colour.

  Maps to a standard ANSI palette slot. The rendered colour depends on the
  terminal emulator's colour scheme.
  """
  @type color ::
          :black
          | :red
          | :green
          | :yellow
          | :blue
          | :magenta
          | :cyan
          | :white
          | :bright_black
          | :bright_red
          | :bright_green
          | :bright_yellow
          | :bright_blue
          | :bright_magenta
          | :bright_cyan
          | :bright_white
          | :default

  @typedoc """
  A border drawing style.
  """
  @type border_style :: :none | :single | :double | :rounded | :thick

  @typedoc """
  A style struct. Build with `new/0` and the pipe-friendly setter functions.
  """
  @type t :: %__MODULE__{
          bold: boolean() | nil,
          dim: boolean() | nil,
          italic: boolean() | nil,
          underline: boolean() | nil,
          strikethrough: boolean() | nil,
          reverse: boolean() | nil,
          foreground: color() | nil,
          background: color() | nil,
          padding: {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil,
          border: border_style() | nil,
          border_fg: color() | nil,
          border_bg: color() | nil
        }

  defstruct bold: nil,
            dim: nil,
            italic: nil,
            underline: nil,
            strikethrough: nil,
            reverse: nil,
            foreground: nil,
            background: nil,
            padding: nil,
            border: nil,
            border_fg: nil,
            border_bg: nil

  @valid_colours [
    :black,
    :red,
    :green,
    :yellow,
    :blue,
    :magenta,
    :cyan,
    :white,
    :bright_black,
    :bright_red,
    :bright_green,
    :bright_yellow,
    :bright_blue,
    :bright_magenta,
    :bright_cyan,
    :bright_white,
    :default
  ]

  @valid_borders [:none, :single, :double, :rounded, :thick]

  # Foreground ANSI codes: standard colours 30-37, bright 90-97, default 39
  @fg_codes %{
    black: 30,
    red: 31,
    green: 32,
    yellow: 33,
    blue: 34,
    magenta: 35,
    cyan: 36,
    white: 37,
    default: 39,
    bright_black: 90,
    bright_red: 91,
    bright_green: 92,
    bright_yellow: 93,
    bright_blue: 94,
    bright_magenta: 95,
    bright_cyan: 96,
    bright_white: 97
  }

  # Background codes are foreground + 10 (40-47, 100-107, 49)
  @bg_codes Map.new(@fg_codes, fn {colour, code} ->
              bg_code = if code == 39, do: 49, else: code + 10
              {colour, bg_code}
            end)

  @border_chars %{
    single: {?┌, ?─, ?┐, ?│, ?│, ?└, ?─, ?┘},
    double: {?╔, ?═, ?╗, ?║, ?║, ?╚, ?═, ?╝},
    rounded: {?╭, ?─, ?╮, ?│, ?│, ?╰, ?─, ?╯},
    thick: {?┏, ?━, ?┓, ?┃, ?┃, ?┗, ?━, ?┛}
  }

  @doc """
  Returns a new `Tela.Style` with all fields unset (`nil`).

  ## Examples

      iex> Tela.Style.new()
      %Tela.Style{}

  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Enables bold text.
  """
  @spec bold(t()) :: t()
  def bold(%__MODULE__{} = style), do: %{style | bold: true}

  @doc """
  Enables dim (faint) text.
  """
  @spec dim(t()) :: t()
  def dim(%__MODULE__{} = style), do: %{style | dim: true}

  @doc """
  Enables italic text.
  """
  @spec italic(t()) :: t()
  def italic(%__MODULE__{} = style), do: %{style | italic: true}

  @doc """
  Enables underlined text.
  """
  @spec underline(t()) :: t()
  def underline(%__MODULE__{} = style), do: %{style | underline: true}

  @doc """
  Enables strikethrough text.
  """
  @spec strikethrough(t()) :: t()
  def strikethrough(%__MODULE__{} = style), do: %{style | strikethrough: true}

  @doc """
  Enables reverse video — swaps the terminal foreground and background colours.

  The rendered character appears as a filled block in the terminal's foreground
  colour. Useful for cursor rendering: `Style.new() |> Style.reverse()` produces
  a solid block that respects the user's terminal colour scheme.
  """
  @spec reverse(t()) :: t()
  def reverse(%__MODULE__{} = style), do: %{style | reverse: true}

  @doc """
  Sets the foreground (text) colour.

  Raises `ArgumentError` if `colour` is not a known colour atom.

  ## Examples

      iex> Tela.Style.new() |> Tela.Style.foreground(:red)
      %Tela.Style{foreground: :red}

  """
  @spec foreground(t(), color()) :: t()
  def foreground(%__MODULE__{} = style, colour) do
    validate_colour!(colour)
    %{style | foreground: colour}
  end

  @doc """
  Sets the background colour.

  Raises `ArgumentError` if `colour` is not a known colour atom.

  ## Examples

      iex> Tela.Style.new() |> Tela.Style.background(:blue)
      %Tela.Style{background: :blue}

  """
  @spec background(t(), color()) :: t()
  def background(%__MODULE__{} = style, colour) do
    validate_colour!(colour)
    %{style | background: colour}
  end

  @doc """
  Sets equal padding on all four sides.
  """
  @spec padding(t(), non_neg_integer()) :: t()
  def padding(%__MODULE__{} = style, all) when is_integer(all) and all >= 0 do
    %{style | padding: {all, all, all, all}}
  end

  @doc """
  Sets vertical (top/bottom) and horizontal (left/right) padding.
  """
  @spec padding(t(), non_neg_integer(), non_neg_integer()) :: t()
  def padding(%__MODULE__{} = style, v, h) when is_integer(v) and v >= 0 and is_integer(h) and h >= 0 do
    %{style | padding: {v, h, v, h}}
  end

  @doc """
  Sets padding explicitly: top, right, bottom, left.
  """
  @spec padding(t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          t()
  def padding(%__MODULE__{} = style, top, right, bottom, left)
      when is_integer(top) and top >= 0 and is_integer(right) and right >= 0 and is_integer(bottom) and bottom >= 0 and
             is_integer(left) and left >= 0 do
    %{style | padding: {top, right, bottom, left}}
  end

  @doc """
  Sets the border style.

  Raises `ArgumentError` if `border_style` is not a known border atom.

  ## Examples

      iex> Tela.Style.new() |> Tela.Style.border(:single)
      %Tela.Style{border: :single}

  """
  @spec border(t(), border_style()) :: t()
  def border(%__MODULE__{} = style, border_style) do
    validate_border!(border_style)
    %{style | border: border_style}
  end

  @doc """
  Sets the foreground colour applied to border characters.

  Raises `ArgumentError` if `colour` is not a known colour atom.
  """
  @spec border_foreground(t(), color()) :: t()
  def border_foreground(%__MODULE__{} = style, colour) do
    validate_colour!(colour)
    %{style | border_fg: colour}
  end

  @doc """
  Sets the background colour applied to border characters.

  Raises `ArgumentError` if `colour` is not a known colour atom.
  """
  @spec border_background(t(), color()) :: t()
  def border_background(%__MODULE__{} = style, colour) do
    validate_colour!(colour)
    %{style | border_bg: colour}
  end

  @doc """
  Applies the style to a string and returns the styled string.

  Supports multi-line strings (containing `\\n`). Lines are normalised to
  equal width before padding and borders are applied. Text attributes and
  colours are applied per-line with a reset at the end of each line.

  ## Examples

      iex> Tela.Style.new() |> Tela.Style.bold() |> Tela.Style.render("hello")
      "\e[1mhello\e[0m"

      iex> Tela.Style.new() |> Tela.Style.render("plain")
      "plain"

  """
  @spec render(t(), String.t()) :: String.t()
  def render(%__MODULE__{} = style, string) when is_binary(string) do
    lines = String.split(string, "\n")

    # Normalise line widths only when padding or border will be applied — both
    # require a rectangular block. Attribute-only styles leave line lengths alone.
    needs_rect = not is_nil(style.padding) or (not is_nil(style.border) and style.border != :none)

    lines =
      if needs_rect do
        max_w = lines |> Enum.map(&String.length/1) |> Enum.max(fn -> 0 end)
        Enum.map(lines, fn line -> String.pad_trailing(line, max_w) end)
      else
        lines
      end

    # Apply padding
    lines = apply_padding(lines, style.padding, 0)

    # Apply text attributes and colours to content lines
    lines = apply_text_style(lines, style)

    # Apply border (wraps already-styled content lines)
    lines = apply_border(lines, style)

    Enum.join(lines, "\n")
  end

  @doc """
  Returns the visible width of a string, stripping ANSI escape codes.

  For multi-line strings, returns the width of the widest line.

  ## Examples

      iex> Tela.Style.width("hello")
      5

      iex> Tela.Style.width("\e[1mhello\e[0m")
      5

      iex> Tela.Style.width("hi\\nworld")
      5

  """
  @spec width(String.t()) :: non_neg_integer()
  def width(string) when is_binary(string) do
    string
    |> strip_ansi()
    |> String.split("\n")
    |> Enum.map(&String.length/1)
    |> Enum.max(fn -> 0 end)
  end

  # Strips all ANSI CSI escape sequences from a string.
  defp strip_ansi(string) do
    Regex.replace(~r/\e\[[0-9;]*[a-zA-Z]/, string, "")
  end

  defp apply_padding(lines, nil, _max_w), do: lines

  defp apply_padding(lines, {top, right, bottom, left}, _max_w) do
    side_pad = fn line -> String.duplicate(" ", left) <> line <> String.duplicate(" ", right) end

    lines
    |> Enum.map(side_pad)
    |> then(fn ls -> List.duplicate("", top) ++ ls ++ List.duplicate("", bottom) end)
  end

  defp apply_text_style(lines, style) do
    open = build_open_codes(style)

    if open == "" do
      lines
    else
      Enum.map(lines, fn line -> open <> line <> "\e[0m" end)
    end
  end

  defp build_open_codes(style) do
    []
    |> maybe_add(style.bold, "\e[1m")
    |> maybe_add(style.dim, "\e[2m")
    |> maybe_add(style.italic, "\e[3m")
    |> maybe_add(style.underline, "\e[4m")
    |> maybe_add(style.strikethrough, "\e[9m")
    |> maybe_add_colour(style.foreground, @fg_codes)
    |> maybe_add_colour(style.background, @bg_codes)
    |> maybe_add(style.reverse, "\e[7m")
    |> Enum.join()
  end

  defp maybe_add(acc, true, code), do: acc ++ [code]
  defp maybe_add(acc, _, _code), do: acc

  defp maybe_add_colour(acc, nil, _codes), do: acc
  defp maybe_add_colour(acc, colour, codes), do: acc ++ ["\e[#{codes[colour]}m"]

  defp apply_border(lines, %{border: nil}), do: lines
  defp apply_border(lines, %{border: :none}), do: lines

  defp apply_border(lines, style) do
    {tl, th, tr, bl, br, bll, bh, blr} = @border_chars[style.border]

    # Visible width of the content lines (strip ANSI since text styles may be applied)
    content_w = lines |> Enum.map(&(&1 |> strip_ansi() |> String.length())) |> Enum.max(fn -> 0 end)

    top_border = border_char(tl) <> String.duplicate(border_char(th), content_w) <> border_char(tr)
    bottom_border = border_char(bll) <> String.duplicate(border_char(bh), content_w) <> border_char(blr)

    content_lines =
      Enum.map(lines, fn line ->
        border_char(bl) <> line <> border_char(br)
      end)

    case {style.border_fg, style.border_bg} do
      {nil, nil} ->
        [top_border] ++ content_lines ++ [bottom_border]

      _ ->
        open = border_colour_open(style.border_fg, style.border_bg)
        close = "\e[0m"

        coloured_top = open <> top_border <> close
        coloured_bottom = open <> bottom_border <> close

        coloured_content =
          Enum.map(lines, fn line ->
            open <> border_char(bl) <> close <> line <> open <> border_char(br) <> close
          end)

        [coloured_top] ++ coloured_content ++ [coloured_bottom]
    end
  end

  defp border_char(codepoint), do: <<codepoint::utf8>>

  defp border_colour_open(fg, bg) do
    []
    |> maybe_add_colour(fg, @fg_codes)
    |> maybe_add_colour(bg, @bg_codes)
    |> Enum.join()
  end

  defp validate_colour!(colour) when colour in @valid_colours, do: :ok

  defp validate_colour!(colour) do
    raise ArgumentError, "unknown colour #{inspect(colour)}. Valid colours: #{inspect(@valid_colours)}"
  end

  defp validate_border!(border) when border in @valid_borders, do: :ok

  defp validate_border!(border) do
    raise ArgumentError, "unknown border style #{inspect(border)}. Valid styles: #{inspect(@valid_borders)}"
  end
end
