defmodule Tela.StylePropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Tela.Style

  @colours [
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

  @border_styles [:none, :single, :double, :rounded, :thick]

  defp colour_gen, do: StreamData.member_of(@colours)
  defp border_gen, do: StreamData.member_of(@border_styles)
  defp padding_gen, do: StreamData.integer(0..4)

  defp style_gen do
    gen all(
          bold <- StreamData.boolean(),
          dim <- StreamData.boolean(),
          italic <- StreamData.boolean(),
          underline <- StreamData.boolean(),
          strikethrough <- StreamData.boolean(),
          reverse <- StreamData.boolean(),
          fg <- StreamData.one_of([StreamData.constant(nil), colour_gen()]),
          bg <- StreamData.one_of([StreamData.constant(nil), colour_gen()]),
          pad <- StreamData.one_of([StreamData.constant(nil), padding_gen()]),
          border <- StreamData.one_of([StreamData.constant(nil), border_gen()]),
          border_fg <- StreamData.one_of([StreamData.constant(nil), colour_gen()]),
          border_bg <- StreamData.one_of([StreamData.constant(nil), colour_gen()])
        ) do
      s = Style.new()
      s = if bold, do: Style.bold(s), else: s
      s = if dim, do: Style.dim(s), else: s
      s = if italic, do: Style.italic(s), else: s
      s = if underline, do: Style.underline(s), else: s
      s = if strikethrough, do: Style.strikethrough(s), else: s
      s = if reverse, do: Style.reverse(s), else: s
      s = if fg, do: Style.foreground(s, fg), else: s
      s = if bg, do: Style.background(s, bg), else: s
      s = if pad, do: Style.padding(s, pad), else: s
      s = if border, do: Style.border(s, border), else: s
      s = if border_fg, do: Style.border_foreground(s, border_fg), else: s
      s = if border_bg, do: Style.border_background(s, border_bg), else: s
      s
    end
  end

  property "render/2 never crashes on arbitrary printable string input with any valid style" do
    check all(
            style <- style_gen(),
            input <- StreamData.string(:printable)
          ) do
      result = Style.render(style, input)
      assert is_binary(result)
    end
  end

  property "width/1 always returns a non-negative integer" do
    check all(input <- StreamData.string(:printable)) do
      assert Style.width(input) >= 0
    end
  end

  property "width/1 of render output equals width of input for attribute-only styles (no padding, no border)" do
    check all(
            input <- StreamData.string(:printable, min_length: 1),
            fg <- StreamData.one_of([StreamData.constant(nil), colour_gen()]),
            bg <- StreamData.one_of([StreamData.constant(nil), colour_gen()]),
            bold <- StreamData.boolean(),
            italic <- StreamData.boolean(),
            reverse <- StreamData.boolean()
          ) do
      s = Style.new()
      s = if bold, do: Style.bold(s), else: s
      s = if italic, do: Style.italic(s), else: s
      s = if reverse, do: Style.reverse(s), else: s
      s = if fg, do: Style.foreground(s, fg), else: s
      s = if bg, do: Style.background(s, bg), else: s

      output = Style.render(s, input)
      assert Style.width(output) == Style.width(input)
    end
  end

  property "render/2 output contains original content for any valid style" do
    check all(
            style <- style_gen(),
            # Use only strings without newlines for this property to simplify containment check
            input <- StreamData.string(:alphanumeric, min_length: 1)
          ) do
      output = Style.render(style, input)
      assert output =~ input
    end
  end
end
