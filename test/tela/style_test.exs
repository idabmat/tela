defmodule Tela.StyleTest do
  use ExUnit.Case, async: true

  alias Tela.Style

  describe "new/0" do
    test "returns a Style struct with all fields nil" do
      s = Style.new()
      assert %Style{} = s
      assert s.bold == nil
      assert s.dim == nil
      assert s.italic == nil
      assert s.underline == nil
      assert s.strikethrough == nil
      assert s.reverse == nil
      assert s.foreground == nil
      assert s.background == nil
      assert s.padding == nil
      assert s.border == nil
      assert s.border_fg == nil
      assert s.border_bg == nil
    end
  end

  describe "attribute setters" do
    test "bold/1 sets bold: true" do
      assert Style.new() |> Style.bold() |> Map.get(:bold) == true
    end

    test "dim/1 sets dim: true" do
      assert Style.new() |> Style.dim() |> Map.get(:dim) == true
    end

    test "italic/1 sets italic: true" do
      assert Style.new() |> Style.italic() |> Map.get(:italic) == true
    end

    test "underline/1 sets underline: true" do
      assert Style.new() |> Style.underline() |> Map.get(:underline) == true
    end

    test "strikethrough/1 sets strikethrough: true" do
      assert Style.new() |> Style.strikethrough() |> Map.get(:strikethrough) == true
    end

    test "reverse/1 sets reverse: true" do
      assert Style.new() |> Style.reverse() |> Map.get(:reverse) == true
    end

    test "setters are pipeable" do
      s = Style.new() |> Style.bold() |> Style.italic() |> Style.underline()
      assert s.bold == true
      assert s.italic == true
      assert s.underline == true
    end
  end

  describe "foreground/2 and background/2" do
    test "foreground/2 sets the foreground colour" do
      assert Style.new() |> Style.foreground(:red) |> Map.get(:foreground) == :red
    end

    test "background/2 sets the background colour" do
      assert Style.new() |> Style.background(:blue) |> Map.get(:background) == :blue
    end

    test "foreground/2 accepts all named colours" do
      colours = [
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

      for colour <- colours do
        assert Style.new() |> Style.foreground(colour) |> Map.get(:foreground) == colour
      end
    end

    test "foreground/2 raises on unknown colour atom" do
      assert_raise ArgumentError, ~r/unknown colour/, fn ->
        Style.foreground(Style.new(), :neon_purple)
      end
    end

    test "background/2 raises on unknown colour atom" do
      assert_raise ArgumentError, ~r/unknown colour/, fn ->
        Style.background(Style.new(), :neon_purple)
      end
    end
  end

  describe "padding/2,3,5" do
    test "padding/2 with a single value sets all four sides" do
      assert Style.new() |> Style.padding(2) |> Map.get(:padding) == {2, 2, 2, 2}
    end

    test "padding/3 with vertical and horizontal sets top/bottom and left/right" do
      assert Style.new() |> Style.padding(1, 2) |> Map.get(:padding) == {1, 2, 1, 2}
    end

    test "padding/5 with four values sets top, right, bottom, left explicitly" do
      assert Style.new() |> Style.padding(1, 2, 3, 4) |> Map.get(:padding) == {1, 2, 3, 4}
    end
  end

  describe "border/2" do
    test "border/2 sets the border style" do
      assert Style.new() |> Style.border(:single) |> Map.get(:border) == :single
    end

    test "border/2 accepts all valid border styles" do
      for b <- [:none, :single, :double, :rounded, :thick] do
        assert Style.new() |> Style.border(b) |> Map.get(:border) == b
      end
    end

    test "border/2 raises on unknown border style" do
      assert_raise ArgumentError, ~r/unknown border/, fn ->
        Style.border(Style.new(), :dotted)
      end
    end

    test "border_foreground/2 sets border_fg" do
      assert Style.new() |> Style.border_foreground(:cyan) |> Map.get(:border_fg) == :cyan
    end

    test "border_background/2 sets border_bg" do
      assert Style.new() |> Style.border_background(:black) |> Map.get(:border_bg) == :black
    end

    test "border_foreground/2 raises on unknown colour" do
      assert_raise ArgumentError, ~r/unknown colour/, fn ->
        Style.border_foreground(Style.new(), :invisible)
      end
    end
  end

  describe "render/2 — no styles" do
    test "plain string is returned unchanged" do
      assert Style.render(Style.new(), "hello") == "hello"
    end

    test "multi-line string is returned unchanged" do
      assert Style.render(Style.new(), "hello\nworld") == "hello\nworld"
    end

    test "multi-line string with unequal line lengths is returned unchanged" do
      assert Style.render(Style.new(), "hi\nworld") == "hi\nworld"
    end
  end

  describe "render/2 — text attributes" do
    test "bold wraps content in bold ANSI codes with per-line reset" do
      output = Style.new() |> Style.bold() |> Style.render("hi")
      assert output == "\e[1mhi\e[0m"
    end

    test "dim wraps content" do
      output = Style.new() |> Style.dim() |> Style.render("hi")
      assert output == "\e[2mhi\e[0m"
    end

    test "italic wraps content" do
      output = Style.new() |> Style.italic() |> Style.render("hi")
      assert output == "\e[3mhi\e[0m"
    end

    test "underline wraps content" do
      output = Style.new() |> Style.underline() |> Style.render("hi")
      assert output == "\e[4mhi\e[0m"
    end

    test "strikethrough wraps content" do
      output = Style.new() |> Style.strikethrough() |> Style.render("hi")
      assert output == "\e[9mhi\e[0m"
    end

    test "reverse wraps content in reverse-video ANSI code" do
      output = Style.new() |> Style.reverse() |> Style.render("hi")
      assert output == "\e[7mhi\e[0m"
    end

    test "foreground + reverse emits foreground then reverse" do
      output = Style.new() |> Style.foreground(:magenta) |> Style.reverse() |> Style.render("x")
      assert output == "\e[35m\e[7mx\e[0m"
    end

    test "multiple attributes combine — open codes precede content, reset follows" do
      output = Style.new() |> Style.bold() |> Style.italic() |> Style.render("hi")
      # Both open codes must appear before content, reset at end
      assert output =~ "\e[1m"
      assert output =~ "\e[3m"
      assert output =~ "hi"
      assert output =~ "\e[0m"
      assert String.ends_with?(output, "\e[0m")
    end

    test "per-line reset — each line gets its own open and reset" do
      output = Style.new() |> Style.bold() |> Style.render("hello\nworld")
      lines = String.split(output, "\n")
      assert length(lines) == 2
      assert Enum.at(lines, 0) =~ "\e[1m"
      assert String.ends_with?(Enum.at(lines, 0), "\e[0m")
      assert Enum.at(lines, 1) =~ "\e[1m"
      assert String.ends_with?(Enum.at(lines, 1), "\e[0m")
    end

    test "reverse + multiline — each line wrapped in reverse-video code and reset" do
      output = Style.new() |> Style.reverse() |> Style.render("hello\nworld")
      lines = String.split(output, "\n")
      assert length(lines) == 2
      assert Enum.at(lines, 0) == "\e[7mhello\e[0m"
      assert Enum.at(lines, 1) == "\e[7mworld\e[0m"
    end
  end

  describe "render/2 — foreground and background colours" do
    test "foreground :black emits \\e[30m" do
      output = Style.new() |> Style.foreground(:black) |> Style.render("x")
      assert output =~ "\e[30m"
      assert output =~ "\e[0m"
    end

    test "foreground :red emits \\e[31m" do
      output = Style.new() |> Style.foreground(:red) |> Style.render("x")
      assert output =~ "\e[31m"
    end

    test "foreground :green emits \\e[32m" do
      output = Style.new() |> Style.foreground(:green) |> Style.render("x")
      assert output =~ "\e[32m"
    end

    test "foreground :yellow emits \\e[33m" do
      output = Style.new() |> Style.foreground(:yellow) |> Style.render("x")
      assert output =~ "\e[33m"
    end

    test "foreground :blue emits \\e[34m" do
      output = Style.new() |> Style.foreground(:blue) |> Style.render("x")
      assert output =~ "\e[34m"
    end

    test "foreground :magenta emits \\e[35m" do
      output = Style.new() |> Style.foreground(:magenta) |> Style.render("x")
      assert output =~ "\e[35m"
    end

    test "foreground :cyan emits \\e[36m" do
      output = Style.new() |> Style.foreground(:cyan) |> Style.render("x")
      assert output =~ "\e[36m"
    end

    test "foreground :white emits \\e[37m" do
      output = Style.new() |> Style.foreground(:white) |> Style.render("x")
      assert output =~ "\e[37m"
    end

    test "foreground :default emits \\e[39m" do
      output = Style.new() |> Style.foreground(:default) |> Style.render("x")
      assert output =~ "\e[39m"
    end

    test "foreground :bright_black emits \\e[90m" do
      output = Style.new() |> Style.foreground(:bright_black) |> Style.render("x")
      assert output =~ "\e[90m"
    end

    test "foreground :bright_white emits \\e[97m" do
      output = Style.new() |> Style.foreground(:bright_white) |> Style.render("x")
      assert output =~ "\e[97m"
    end

    test "background :black emits \\e[40m" do
      output = Style.new() |> Style.background(:black) |> Style.render("x")
      assert output =~ "\e[40m"
    end

    test "background :red emits \\e[41m" do
      output = Style.new() |> Style.background(:red) |> Style.render("x")
      assert output =~ "\e[41m"
    end

    test "background :bright_black emits \\e[100m" do
      output = Style.new() |> Style.background(:bright_black) |> Style.render("x")
      assert output =~ "\e[100m"
    end

    test "background :green emits \\e[42m" do
      output = Style.new() |> Style.background(:green) |> Style.render("x")
      assert output =~ "\e[42m"
    end

    test "background :yellow emits \\e[43m" do
      output = Style.new() |> Style.background(:yellow) |> Style.render("x")
      assert output =~ "\e[43m"
    end

    test "background :blue emits \\e[44m" do
      output = Style.new() |> Style.background(:blue) |> Style.render("x")
      assert output =~ "\e[44m"
    end

    test "background :magenta emits \\e[45m" do
      output = Style.new() |> Style.background(:magenta) |> Style.render("x")
      assert output =~ "\e[45m"
    end

    test "background :cyan emits \\e[46m" do
      output = Style.new() |> Style.background(:cyan) |> Style.render("x")
      assert output =~ "\e[46m"
    end

    test "background :white emits \\e[47m" do
      output = Style.new() |> Style.background(:white) |> Style.render("x")
      assert output =~ "\e[47m"
    end

    test "background :default emits \\e[49m" do
      output = Style.new() |> Style.background(:default) |> Style.render("x")
      assert output =~ "\e[49m"
    end

    test "background :bright_red emits \\e[101m" do
      output = Style.new() |> Style.background(:bright_red) |> Style.render("x")
      assert output =~ "\e[101m"
    end

    test "background :bright_green emits \\e[102m" do
      output = Style.new() |> Style.background(:bright_green) |> Style.render("x")
      assert output =~ "\e[102m"
    end

    test "background :bright_yellow emits \\e[103m" do
      output = Style.new() |> Style.background(:bright_yellow) |> Style.render("x")
      assert output =~ "\e[103m"
    end

    test "background :bright_blue emits \\e[104m" do
      output = Style.new() |> Style.background(:bright_blue) |> Style.render("x")
      assert output =~ "\e[104m"
    end

    test "background :bright_magenta emits \\e[105m" do
      output = Style.new() |> Style.background(:bright_magenta) |> Style.render("x")
      assert output =~ "\e[105m"
    end

    test "background :bright_cyan emits \\e[106m" do
      output = Style.new() |> Style.background(:bright_cyan) |> Style.render("x")
      assert output =~ "\e[106m"
    end

    test "background :bright_white emits \\e[107m" do
      output = Style.new() |> Style.background(:bright_white) |> Style.render("x")
      assert output =~ "\e[107m"
    end

    test "foreground and background codes both appear in output" do
      output = Style.new() |> Style.foreground(:cyan) |> Style.background(:black) |> Style.render("x")
      assert output =~ "\e[36m"
      assert output =~ "\e[40m"
    end
  end

  describe "render/2 — padding" do
    test "left padding of 1 prepends one space to each line" do
      output = Style.new() |> Style.padding(0, 0, 0, 1) |> Style.render("hi")
      assert output == " hi"
    end

    test "right padding of 1 appends one space to each line" do
      output = Style.new() |> Style.padding(0, 1, 0, 0) |> Style.render("hi")
      assert output == "hi "
    end

    test "top padding of 1 prepends a blank line" do
      output = Style.new() |> Style.padding(1, 0, 0, 0) |> Style.render("hi")
      lines = String.split(output, "\n")
      assert length(lines) == 2
      assert Enum.at(lines, 0) == ""
      assert Enum.at(lines, 1) == "hi"
    end

    test "bottom padding of 1 appends a blank line" do
      output = Style.new() |> Style.padding(0, 0, 1, 0) |> Style.render("hi")
      lines = String.split(output, "\n")
      assert length(lines) == 2
      assert Enum.at(lines, 0) == "hi"
      assert Enum.at(lines, 1) == ""
    end

    test "symmetric padding/2 adds equal space on all sides" do
      output = Style.new() |> Style.padding(1) |> Style.render("hi")
      lines = String.split(output, "\n")
      # top blank, content line, bottom blank
      assert length(lines) == 3
      assert Enum.at(lines, 0) == ""
      assert Enum.at(lines, 1) == " hi "
      assert Enum.at(lines, 2) == ""
    end

    test "multi-line input with left/right padding pads every line" do
      output = Style.new() |> Style.padding(0, 1, 0, 1) |> Style.render("ab\ncd")
      lines = String.split(output, "\n")
      assert Enum.at(lines, 0) == " ab "
      assert Enum.at(lines, 1) == " cd "
    end

    test "multi-line with unequal widths — shorter lines padded to match longest before side padding" do
      output = Style.new() |> Style.padding(0, 0, 0, 1) |> Style.render("hi\nworld")
      lines = String.split(output, "\n")
      # Both lines get left-padding; shorter line normalised to width of "world"
      assert Enum.at(lines, 0) == " hi   "
      assert Enum.at(lines, 1) == " world"
    end
  end

  describe "render/2 — border" do
    test "single border wraps a single-line string" do
      output = Style.new() |> Style.border(:single) |> Style.render("hi")
      lines = String.split(output, "\n")
      assert length(lines) == 3
      assert Enum.at(lines, 0) == "┌──┐"
      assert Enum.at(lines, 1) == "│hi│"
      assert Enum.at(lines, 2) == "└──┘"
    end

    test "double border uses correct box-drawing characters" do
      output = Style.new() |> Style.border(:double) |> Style.render("hi")
      lines = String.split(output, "\n")
      assert Enum.at(lines, 0) == "╔══╗"
      assert Enum.at(lines, 1) == "║hi║"
      assert Enum.at(lines, 2) == "╚══╝"
    end

    test "rounded border uses rounded corners" do
      output = Style.new() |> Style.border(:rounded) |> Style.render("hi")
      lines = String.split(output, "\n")
      assert Enum.at(lines, 0) == "╭──╮"
      assert Enum.at(lines, 1) == "│hi│"
      assert Enum.at(lines, 2) == "╰──╯"
    end

    test "thick border uses heavy box-drawing characters" do
      output = Style.new() |> Style.border(:thick) |> Style.render("hi")
      lines = String.split(output, "\n")
      assert Enum.at(lines, 0) == "┏━━┓"
      assert Enum.at(lines, 1) == "┃hi┃"
      assert Enum.at(lines, 2) == "┗━━┛"
    end

    test "border :none produces no border characters" do
      output = Style.new() |> Style.border(:none) |> Style.render("hi")
      assert output == "hi"
    end

    test "border wraps multi-line content" do
      output = Style.new() |> Style.border(:single) |> Style.render("ab\ncd")
      lines = String.split(output, "\n")
      assert length(lines) == 4
      assert Enum.at(lines, 0) == "┌──┐"
      assert Enum.at(lines, 1) == "│ab│"
      assert Enum.at(lines, 2) == "│cd│"
      assert Enum.at(lines, 3) == "└──┘"
    end

    test "border width spans the widest line" do
      output = Style.new() |> Style.border(:single) |> Style.render("hi\nworld")
      lines = String.split(output, "\n")
      # "world" is 5 chars wide — border top/bottom should be 5 dashes
      assert Enum.at(lines, 0) == "┌─────┐"
      assert Enum.at(lines, 1) == "│hi   │"
      assert Enum.at(lines, 2) == "│world│"
      assert Enum.at(lines, 3) == "└─────┘"
    end
  end

  describe "render/2 — border colours" do
    test "border_foreground colours the border characters" do
      output =
        Style.new()
        |> Style.border(:single)
        |> Style.border_foreground(:cyan)
        |> Style.render("hi")

      lines = String.split(output, "\n")
      # Top border line must contain cyan open code and reset
      assert Enum.at(lines, 0) =~ "\e[36m"
      assert Enum.at(lines, 0) =~ "\e[0m"
      # Content line border chars must be coloured
      assert Enum.at(lines, 1) =~ "\e[36m"
      # Content itself must be present
      assert Enum.at(lines, 1) =~ "hi"
    end

    test "border_background colours the border characters" do
      output =
        Style.new()
        |> Style.border(:single)
        |> Style.border_background(:blue)
        |> Style.render("hi")

      lines = String.split(output, "\n")
      # Top border line must contain blue background code (44) and reset
      assert Enum.at(lines, 0) =~ "\e[44m"
      assert Enum.at(lines, 0) =~ "\e[0m"
      # Content line border chars must carry bg colour
      assert Enum.at(lines, 1) =~ "\e[44m"
      # Content itself must be present
      assert Enum.at(lines, 1) =~ "hi"
    end

    test "border_foreground + border_background both appear on border lines" do
      output =
        Style.new()
        |> Style.border(:single)
        |> Style.border_foreground(:cyan)
        |> Style.border_background(:blue)
        |> Style.render("hi")

      lines = String.split(output, "\n")
      assert Enum.at(lines, 0) =~ "\e[36m"
      assert Enum.at(lines, 0) =~ "\e[44m"
    end

    test "border colours do not bleed into content" do
      output =
        Style.new()
        |> Style.border(:single)
        |> Style.border_foreground(:red)
        |> Style.render("hello")

      lines = String.split(output, "\n")
      content_line = Enum.at(lines, 1)
      # After opening border char + reset, content appears without colour code
      # Structure: <red>│<reset>hello<red>│<reset>
      assert content_line =~ "\e[31m│\e[0m"
      assert content_line =~ "\e[0mhello\e[31m│\e[0m" or content_line =~ "\e[0m" <> "hello"
    end
  end

  describe "render/2 — composed styles" do
    test "bold + foreground colour — both codes present with reset" do
      output = Style.new() |> Style.bold() |> Style.foreground(:green) |> Style.render("ok")
      assert output =~ "\e[1m"
      assert output =~ "\e[32m"
      assert output =~ "ok"
      assert String.ends_with?(output, "\e[0m")
    end

    test "padding + border compose correctly" do
      output =
        Style.new()
        |> Style.padding(0, 1, 0, 1)
        |> Style.border(:single)
        |> Style.render("hi")

      lines = String.split(output, "\n")
      # padding 1 each side → content line is " hi "
      assert length(lines) == 3
      assert Enum.at(lines, 0) == "┌────┐"
      assert Enum.at(lines, 1) == "│ hi │"
      assert Enum.at(lines, 2) == "└────┘"
    end

    test "bold + border — content lines are bold, border chars are plain" do
      output =
        Style.new()
        |> Style.bold()
        |> Style.border(:single)
        |> Style.render("hi")

      lines = String.split(output, "\n")
      # Border lines have no bold code
      refute Enum.at(lines, 0) =~ "\e[1m"
      refute Enum.at(lines, 2) =~ "\e[1m"
      # Content line has bold code
      assert Enum.at(lines, 1) =~ "\e[1m"
    end
  end

  describe "width/1" do
    test "returns the length of a plain string" do
      assert Style.width("hello") == 5
    end

    test "returns 0 for empty string" do
      assert Style.width("") == 0
    end

    test "strips ANSI escape codes before measuring" do
      assert Style.width("\e[1mhello\e[0m") == 5
    end

    test "strips foreground colour codes" do
      assert Style.width("\e[31mred\e[0m") == 3
    end

    test "returns width of the widest line for multi-line strings" do
      assert Style.width("hi\nworld") == 5
    end

    test "width of render output equals width of input for attribute-only styles" do
      input = "hello"
      output = Style.new() |> Style.bold() |> Style.foreground(:red) |> Style.render(input)
      assert Style.width(output) == Style.width(input)
    end
  end
end
