defmodule Tela.Component.TextInputPropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Tela.Component.TextInput

  defp printable_char_gen do
    # Printable ASCII excluding control characters: 0x20..0x7E
    StreamData.map(StreamData.integer(0x20..0x7E), &<<&1>>)
  end

  defp value_gen do
    StreamData.map(StreamData.list_of(printable_char_gen(), max_length: 40), &Enum.join/1)
  end

  property "cursor is always within bounds after any sequence of insertions" do
    check all(chars <- StreamData.list_of(printable_char_gen(), max_length: 50)) do
      ti =
        Enum.reduce(chars, [cursor_mode: :static] |> TextInput.init() |> TextInput.focus(), fn char, acc ->
          {new_ti, _cmd} = TextInput.handle_event(acc, %Tela.Key{key: {:char, char}, raw: char})
          new_ti
        end)

      len = ti.value |> String.graphemes() |> length()
      assert ti.cursor >= 0
      assert ti.cursor <= len
    end
  end

  property "cursor is always within bounds after insert + backspace operations" do
    check all(
            value <- value_gen(),
            n_backspace <- StreamData.integer(0..20)
          ) do
      ti =
        [cursor_mode: :static]
        |> TextInput.init()
        |> TextInput.focus()
        |> TextInput.set_value(value)

      ti =
        Enum.reduce(1..max(n_backspace, 1), ti, fn _, acc ->
          {new_ti, _cmd} = TextInput.handle_event(acc, %Tela.Key{key: :backspace, raw: ""})
          new_ti
        end)

      len = ti.value |> String.graphemes() |> length()
      assert ti.cursor >= 0
      assert ti.cursor <= len
    end
  end

  property "value grapheme count never exceeds char_limit when set" do
    check all(
            limit <- StreamData.integer(1..20),
            chars <- StreamData.list_of(printable_char_gen(), max_length: 40)
          ) do
      ti =
        Enum.reduce(
          chars,
          [cursor_mode: :static, char_limit: limit] |> TextInput.init() |> TextInput.focus(),
          fn char, acc ->
            {new_ti, _cmd} = TextInput.handle_event(acc, %Tela.Key{key: {:char, char}, raw: char})
            new_ti
          end
        )

      assert ti.value |> String.graphemes() |> length() <= limit
    end
  end

  property "insert then backspace at end leaves value unchanged" do
    check all(
            value <- value_gen(),
            char <- printable_char_gen()
          ) do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value(value)
      {ti_after_insert, _} = TextInput.handle_event(ti, %Tela.Key{key: {:char, char}, raw: char})
      {ti_after_backspace, _} = TextInput.handle_event(ti_after_insert, %Tela.Key{key: :backspace, raw: ""})
      assert ti_after_backspace.value == value
      assert ti_after_backspace.cursor == ti.cursor
    end
  end

  property "view/1 never crashes on any valid model state" do
    check all(
            value <- value_gen(),
            focused <- StreamData.boolean(),
            cursor_mode <- StreamData.member_of([:blink, :static, :hidden]),
            echo_mode <- StreamData.member_of([:normal, :password, :none])
          ) do
      ti =
        [cursor_mode: cursor_mode, echo_mode: echo_mode]
        |> TextInput.init()
        |> TextInput.set_value(value)
        |> then(fn t -> if focused, do: TextInput.focus(t), else: t end)

      result = TextInput.view(ti)
      assert %Tela.Frame{} = result
      assert is_binary(result.content)
      assert result.cursor == nil
    end
  end

  property "view/1 output content always contains the value (in normal echo mode, blurred)" do
    check all(value <- StreamData.string(:alphanumeric, min_length: 1)) do
      ti = [prompt: "", cursor_mode: :static] |> TextInput.init() |> TextInput.set_value(value)
      assert TextInput.view(ti).content =~ value
    end
  end
end
