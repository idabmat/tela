defmodule Tela.Component.TextInputTest do
  use ExUnit.Case, async: true

  alias Tela.Component.TextInput
  alias Tela.Style

  defp key(k), do: %Tela.Key{key: k, raw: ""}

  describe "init/1" do
    test "defaults: empty value, cursor 0, prompt '> ', not focused, echo :normal, echo_char *" do
      ti = TextInput.init([])
      assert ti.value == ""
      assert ti.cursor == 0
      assert ti.prompt == "> "
      assert ti.placeholder == ""
      assert ti.char_limit == 0
      assert ti.echo_mode == :normal
      assert ti.echo_char == "*"
      assert ti.focused == false
      assert ti.focused_style == Style.new()
      assert ti.blurred_style == Style.new()
    end

    test "echo_char: option" do
      ti = TextInput.init(echo_char: "•")
      assert ti.echo_char == "•"
    end

    test "prompt: option" do
      ti = TextInput.init(prompt: "Name: ")
      assert ti.prompt == "Name: "
    end

    test "placeholder: option" do
      ti = TextInput.init(placeholder: "Pikachu")
      assert ti.placeholder == "Pikachu"
    end

    test "char_limit: option" do
      ti = TextInput.init(char_limit: 10)
      assert ti.char_limit == 10
    end

    test "echo_mode: :password" do
      ti = TextInput.init(echo_mode: :password)
      assert ti.echo_mode == :password
    end

    test "echo_mode: :none" do
      ti = TextInput.init(echo_mode: :none)
      assert ti.echo_mode == :none
    end

    test "focused_style: option" do
      style = Style.foreground(Style.new(), :cyan)
      ti = TextInput.init(focused_style: style)
      assert ti.focused_style == style
    end

    test "blurred_style: option" do
      style = Style.foreground(Style.new(), :bright_black)
      ti = TextInput.init(blurred_style: style)
      assert ti.blurred_style == style
    end
  end

  describe "focus/1 and blur/1" do
    test "focus/1 sets focused true" do
      ti = [] |> TextInput.init() |> TextInput.focus()
      assert ti.focused == true
    end

    test "blur/1 sets focused false" do
      ti = [] |> TextInput.init() |> TextInput.focus() |> TextInput.blur()
      assert ti.focused == false
    end
  end

  describe "value/1 and set_value/2" do
    test "value/1 returns current value" do
      ti = TextInput.init([])
      assert TextInput.value(ti) == ""
    end

    test "set_value/2 replaces value and moves cursor to end" do
      ti = [] |> TextInput.init() |> TextInput.set_value("hello")
      assert ti.value == "hello"
      assert ti.cursor == 5
    end

    test "set_value/2 clamps to char_limit" do
      ti = [char_limit: 3] |> TextInput.init() |> TextInput.set_value("hello")
      assert ti.value == "hel"
      assert ti.cursor == 3
    end

    test "set_value/2 with no limit accepts full string" do
      ti = [] |> TextInput.init() |> TextInput.set_value("hello world")
      assert ti.value == "hello world"
    end
  end

  describe "handle_event/2 — insert" do
    test "printable char inserted at cursor end" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus()
      {ti, nil} = TextInput.handle_event(ti, key({:char, "a"}))
      assert ti.value == "a"
      assert ti.cursor == 1
    end

    test "printable char inserted mid-value" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("ac")
      ti = %{ti | cursor: 1}
      {ti, nil} = TextInput.handle_event(ti, key({:char, "b"}))
      assert ti.value == "abc"
      assert ti.cursor == 2
    end

    test "char respects char_limit" do
      ti = [cursor_mode: :static, char_limit: 2] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("ab")
      {ti, nil} = TextInput.handle_event(ti, key({:char, "c"}))
      assert ti.value == "ab"
      assert ti.cursor == 2
    end

    test "ignored when not focused" do
      ti = TextInput.init([])
      {new_ti, nil} = TextInput.handle_event(ti, key({:char, "a"}))
      assert new_ti == ti
    end
  end

  describe "handle_event/2 — backspace" do
    test "deletes char before cursor" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("ab")
      {ti, nil} = TextInput.handle_event(ti, key(:backspace))
      assert ti.value == "a"
      assert ti.cursor == 1
    end

    test "no-op at position 0" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus()
      {new_ti, nil} = TextInput.handle_event(ti, key(:backspace))
      assert new_ti.value == ""
      assert new_ti.cursor == 0
    end

    test "deletes grapheme before cursor mid-value" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("abc")
      ti = %{ti | cursor: 2}
      {ti, nil} = TextInput.handle_event(ti, key(:backspace))
      assert ti.value == "ac"
      assert ti.cursor == 1
    end

    test "ctrl+h deletes char before cursor (terminal backspace alias)" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("ab")
      {ti, nil} = TextInput.handle_event(ti, key({:ctrl, "h"}))
      assert ti.value == "a"
      assert ti.cursor == 1
    end

    test "ctrl+h no-op at position 0" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus()
      {new_ti, nil} = TextInput.handle_event(ti, key({:ctrl, "h"}))
      assert new_ti.value == ""
      assert new_ti.cursor == 0
    end
  end

  describe "handle_event/2 — delete" do
    test "delete removes char at cursor" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("ab")
      ti = %{ti | cursor: 0}
      {ti, nil} = TextInput.handle_event(ti, key(:delete))
      assert ti.value == "b"
      assert ti.cursor == 0
    end

    test "ctrl+d removes char at cursor" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("ab")
      ti = %{ti | cursor: 0}
      {ti, nil} = TextInput.handle_event(ti, key({:ctrl, "d"}))
      assert ti.value == "b"
      assert ti.cursor == 0
    end

    test "delete at end of value is no-op" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("ab")
      {new_ti, nil} = TextInput.handle_event(ti, key(:delete))
      assert new_ti.value == "ab"
    end
  end

  describe "handle_event/2 — ctrl+k and ctrl+u" do
    test "ctrl+k deletes from cursor to end" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello")
      ti = %{ti | cursor: 2}
      {ti, nil} = TextInput.handle_event(ti, key({:ctrl, "k"}))
      assert ti.value == "he"
      assert ti.cursor == 2
    end

    test "ctrl+u deletes from start to cursor" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello")
      ti = %{ti | cursor: 3}
      {ti, nil} = TextInput.handle_event(ti, key({:ctrl, "u"}))
      assert ti.value == "lo"
      assert ti.cursor == 0
    end

    test "ctrl+k at cursor 0 deletes entire value" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello")
      ti = %{ti | cursor: 0}
      {ti, nil} = TextInput.handle_event(ti, key({:ctrl, "k"}))
      assert ti.value == ""
      assert ti.cursor == 0
    end

    test "ctrl+k at end of value is no-op" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello")
      {new_ti, nil} = TextInput.handle_event(ti, key({:ctrl, "k"}))
      assert new_ti.value == "hello"
      assert new_ti.cursor == 5
    end

    test "ctrl+u at cursor 0 is no-op" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello")
      ti = %{ti | cursor: 0}
      {new_ti, nil} = TextInput.handle_event(ti, key({:ctrl, "u"}))
      assert new_ti.value == "hello"
      assert new_ti.cursor == 0
    end
  end

  describe "handle_event/2 — ctrl+w (delete word backward)" do
    test "deletes word before cursor" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello world")
      {ti, nil} = TextInput.handle_event(ti, key({:ctrl, "w"}))
      assert ti.value == "hello "
      assert ti.cursor == 6
    end

    test "deletes trailing spaces then word" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello   ")
      {ti, nil} = TextInput.handle_event(ti, key({:ctrl, "w"}))
      assert ti.value == ""
      assert ti.cursor == 0
    end

    test "no-op at position 0" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus()
      {new_ti, nil} = TextInput.handle_event(ti, key({:ctrl, "w"}))
      assert new_ti.value == ""
      assert new_ti.cursor == 0
    end

    test "deletes leading spaces then word when value ends in spaces before cursor" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("foo  bar  ")
      {ti, nil} = TextInput.handle_event(ti, key({:ctrl, "w"}))
      assert ti.value == "foo  "
      assert ti.cursor == 5
    end
  end

  describe "handle_event/2 — word navigation" do
    test "alt+f moves cursor forward past next word" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello world")
      ti = %{ti | cursor: 0}
      {ti, nil} = TextInput.handle_event(ti, key({:alt, "f"}))
      assert ti.cursor == 5
    end

    test "alt+f skips leading spaces then stops at end of word" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello world")
      ti = %{ti | cursor: 5}
      {ti, nil} = TextInput.handle_event(ti, key({:alt, "f"}))
      assert ti.cursor == 11
    end

    test "alt+f at end of value is no-op" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello")
      {new_ti, nil} = TextInput.handle_event(ti, key({:alt, "f"}))
      assert new_ti.cursor == 5
    end

    test "alt+f in password mode jumps to end" do
      ti =
        [cursor_mode: :static, echo_mode: :password]
        |> TextInput.init()
        |> TextInput.focus()
        |> TextInput.set_value("hello world")

      ti = %{ti | cursor: 0}
      {ti, nil} = TextInput.handle_event(ti, key({:alt, "f"}))
      assert ti.cursor == 11
    end

    test "alt+b moves cursor backward past previous word" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello world")
      {ti, nil} = TextInput.handle_event(ti, key({:alt, "b"}))
      assert ti.cursor == 6
    end

    test "alt+b from start of word skips spaces then moves backward" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello world")
      ti = %{ti | cursor: 6}
      {ti, nil} = TextInput.handle_event(ti, key({:alt, "b"}))
      assert ti.cursor == 0
    end

    test "alt+b at position 0 is no-op" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello")
      ti = %{ti | cursor: 0}
      {new_ti, nil} = TextInput.handle_event(ti, key({:alt, "b"}))
      assert new_ti.cursor == 0
    end

    test "alt+b in password mode jumps to start" do
      ti =
        [cursor_mode: :static, echo_mode: :password]
        |> TextInput.init()
        |> TextInput.focus()
        |> TextInput.set_value("hello world")

      {ti, nil} = TextInput.handle_event(ti, key({:alt, "b"}))
      assert ti.cursor == 0
    end
  end

  describe "handle_event/2 — delete_word_forward" do
    test "alt+d deletes from cursor to end of next word" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello world")
      ti = %{ti | cursor: 0}
      {ti, nil} = TextInput.handle_event(ti, key({:alt, "d"}))
      assert ti.value == " world"
      assert ti.cursor == 0
    end

    test "alt+d skips leading spaces then deletes word" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello world")
      ti = %{ti | cursor: 5}
      {ti, nil} = TextInput.handle_event(ti, key({:alt, "d"}))
      assert ti.value == "hello"
      assert ti.cursor == 5
    end

    test "alt+d at end of value is no-op" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello")
      {new_ti, nil} = TextInput.handle_event(ti, key({:alt, "d"}))
      assert new_ti.value == "hello"
      assert new_ti.cursor == 5
    end

    test "alt+d in password mode deletes everything after cursor" do
      ti =
        [cursor_mode: :static, echo_mode: :password]
        |> TextInput.init()
        |> TextInput.focus()
        |> TextInput.set_value("hello world")

      ti = %{ti | cursor: 3}
      {ti, nil} = TextInput.handle_event(ti, key({:alt, "d"}))
      assert ti.value == "hel"
      assert ti.cursor == 3
    end
  end

  describe "handle_event/2 — navigation" do
    test "left moves cursor left" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("ab")
      {ti, nil} = TextInput.handle_event(ti, key(:left))
      assert ti.cursor == 1
    end

    test "left at position 0 is no-op" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus()
      {new_ti, nil} = TextInput.handle_event(ti, key(:left))
      assert new_ti.cursor == 0
    end

    test "ctrl+b moves cursor left" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("ab")
      {ti, nil} = TextInput.handle_event(ti, key({:ctrl, "b"}))
      assert ti.cursor == 1
    end

    test "right moves cursor right" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("ab")
      ti = %{ti | cursor: 0}
      {ti, nil} = TextInput.handle_event(ti, key(:right))
      assert ti.cursor == 1
    end

    test "right at end is no-op" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("ab")
      {new_ti, nil} = TextInput.handle_event(ti, key(:right))
      assert new_ti.cursor == 2
    end

    test "ctrl+f moves cursor right" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("ab")
      ti = %{ti | cursor: 0}
      {ti, nil} = TextInput.handle_event(ti, key({:ctrl, "f"}))
      assert ti.cursor == 1
    end

    test "home moves cursor to start" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello")
      {ti, nil} = TextInput.handle_event(ti, key(:home))
      assert ti.cursor == 0
    end

    test "ctrl+a moves cursor to start" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello")
      {ti, nil} = TextInput.handle_event(ti, key({:ctrl, "a"}))
      assert ti.cursor == 0
    end

    test "end moves cursor to end" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello")
      ti = %{ti | cursor: 0}
      {ti, nil} = TextInput.handle_event(ti, key(:end))
      assert ti.cursor == 5
    end

    test "ctrl+e moves cursor to end" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hello")
      ti = %{ti | cursor: 0}
      {ti, nil} = TextInput.handle_event(ti, key({:ctrl, "e"}))
      assert ti.cursor == 5
    end
  end

  describe "handle_event/2 — cursor reset on keypress" do
    test "resets cursor_visible to true and re-arms blink on keypress" do
      ti = [] |> TextInput.init() |> TextInput.focus()
      ti = %{ti | cursor_visible: false}
      {new_ti, cmd} = TextInput.handle_event(ti, key({:char, "a"}))
      assert new_ti.cursor_visible == true
      assert {:task, _} = cmd
    end

    test "rotates cursor_id on keypress resetting stale-tick guard" do
      ti = [] |> TextInput.init() |> TextInput.focus()
      old_id = ti.cursor_id
      {new_ti, _cmd} = TextInput.handle_event(ti, key({:char, "a"}))
      assert new_ti.cursor_id != old_id
    end

    test "no blink cmd on keypress when mode is :static" do
      ti = [cursor_mode: :static] |> TextInput.init() |> TextInput.focus()
      {_new_ti, cmd} = TextInput.handle_event(ti, key({:char, "a"}))
      assert cmd == nil
    end
  end

  describe "view/1" do
    test "returns a Tela.Frame" do
      ti = TextInput.init([])
      assert %Tela.Frame{} = TextInput.view(ti)
    end

    test "renders prompt + value when focused" do
      ti = [prompt: "> "] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hi")
      frame = TextInput.view(ti)
      cursor_char = Style.render(Style.reverse(Style.new()), " ")
      assert frame.content == "> hi" <> cursor_char
    end

    test "frame.cursor is nil when focused (virtual cursor only)" do
      ti = [prompt: "> "] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hi")
      frame = TextInput.view(ti)
      assert frame.cursor == nil
    end

    test "focused with no style: reverse-video cursor char embedded in content mid-value" do
      ti = [prompt: ""] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("abc")
      ti = %{ti | cursor: 1}
      frame = TextInput.view(ti)
      cursor_char = Style.render(Style.reverse(Style.new()), "b")
      assert frame.content == "a" <> cursor_char <> "c"
    end

    test "focused with no style: reverse-video space at end when cursor past last char" do
      ti = [prompt: ""] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hi")
      frame = TextInput.view(ti)
      cursor_char = Style.render(Style.reverse(Style.new()), " ")
      assert frame.content == "hi" <> cursor_char
    end

    test "cursor is nil when blurred" do
      ti = [prompt: ""] |> TextInput.init() |> TextInput.set_value("hi")
      frame = TextInput.view(ti)
      assert frame.cursor == nil
    end

    test "content renders value when blurred" do
      ti = [prompt: ""] |> TextInput.init() |> TextInput.set_value("hi")
      frame = TextInput.view(ti)
      assert frame.content == "hi"
    end

    test "placeholder rendered when value empty and blurred" do
      ti = TextInput.init(prompt: "", placeholder: "Pikachu")
      frame = TextInput.view(ti)
      dim_style = Style.foreground(Style.new(), :bright_black)
      assert frame.content == Style.render(dim_style, "Pikachu")
      assert frame.cursor == nil
    end

    test "focused + empty + placeholder — cursor char on first placeholder grapheme, rest dim" do
      ti = [prompt: "", placeholder: "Pikachu"] |> TextInput.init() |> TextInput.focus()
      frame = TextInput.view(ti)
      dim_style = Style.foreground(Style.new(), :bright_black)
      cursor_char = Style.render(Style.reverse(Style.new()), "P")
      assert frame.content == cursor_char <> Style.render(dim_style, "ikachu")
      assert frame.cursor == nil
    end

    test "focused + empty + no placeholder — content is reversed space, cursor nil" do
      ti = [prompt: ""] |> TextInput.init() |> TextInput.focus()
      frame = TextInput.view(ti)
      cursor_char = Style.render(Style.reverse(Style.new()), " ")
      assert frame.content == cursor_char
      assert frame.cursor == nil
    end

    test "focused + empty + no placeholder + prompt — frame.cursor nil" do
      ti = [prompt: "> "] |> TextInput.init() |> TextInput.focus()
      frame = TextInput.view(ti)
      assert frame.cursor == nil
    end

    test "password mode content masked with default echo_char *" do
      ti = [prompt: "", echo_mode: :password] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("secret")
      frame = TextInput.view(ti)
      cursor_char = Style.render(Style.reverse(Style.new()), " ")
      assert frame.content == "******" <> cursor_char
    end

    test "password mode frame.cursor is nil (virtual cursor only)" do
      ti = [prompt: "", echo_mode: :password] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("secret")
      frame = TextInput.view(ti)
      assert frame.cursor == nil
    end

    test "password mode uses custom echo_char" do
      ti =
        [prompt: "", echo_mode: :password, echo_char: "•"]
        |> TextInput.init()
        |> TextInput.focus()
        |> TextInput.set_value("abc")

      frame = TextInput.view(ti)
      cursor_char = Style.render(Style.reverse(Style.new()), " ")
      assert frame.content == "•••" <> cursor_char
    end

    test "password mode frame.cursor is nil mid-value (virtual cursor only)" do
      ti = [prompt: "", echo_mode: :password] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("abc")
      ti = %{ti | cursor: 1}
      frame = TextInput.view(ti)
      assert frame.cursor == nil
    end

    test "echo_none mode: focused — content is prompt + cursor space, frame.cursor nil" do
      ti =
        [prompt: "> ", cursor_mode: :static, echo_mode: :none]
        |> TextInput.init()
        |> TextInput.focus()
        |> TextInput.set_value("secret")

      frame = TextInput.view(ti)
      cursor_char = Style.render(Style.reverse(Style.new()), " ")
      assert frame.content == "> " <> cursor_char
      assert frame.cursor == nil
    end

    test "echo_none mode: blurred — content is just prompt, cursor nil" do
      ti = [prompt: "> ", echo_mode: :none] |> TextInput.init() |> TextInput.set_value("secret")
      frame = TextInput.view(ti)
      assert frame.content == "> "
      assert frame.cursor == nil
    end

    test "echo_none mode: focused + placeholder — cursor char on first placeholder grapheme, frame.cursor nil" do
      ti =
        [prompt: "", cursor_mode: :static, echo_mode: :none, placeholder: "hidden"]
        |> TextInput.init()
        |> TextInput.focus()

      frame = TextInput.view(ti)
      dim_style = Style.foreground(Style.new(), :bright_black)
      cursor_char = Style.render(Style.reverse(Style.new()), "h")
      assert frame.content == cursor_char <> Style.render(dim_style, "idden")
      assert frame.cursor == nil
    end

    test "default cursor_mode is :blink" do
      ti = TextInput.init([])
      assert ti.cursor_mode == :blink
    end

    test "cursor_mode: :static option" do
      ti = TextInput.init(cursor_mode: :static)
      assert ti.cursor_mode == :static
    end

    test "cursor_mode: :hidden option" do
      ti = TextInput.init(cursor_mode: :hidden)
      assert ti.cursor_mode == :hidden
    end

    test "cursor_visible starts true" do
      ti = TextInput.init([])
      assert ti.cursor_visible == true
    end

    test "focused_style applied to prompt and text when focused, cursor char reversed" do
      style = Style.foreground(Style.new(), :cyan)
      ti = [prompt: "> ", focused_style: style] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hi")
      frame = TextInput.view(ti)
      cursor_char = Style.render(Style.reverse(style), " ")
      assert frame.content == Style.render(style, "> hi") <> cursor_char
    end

    test "focused_style: frame.cursor is nil (virtual cursor carries the colour)" do
      style = Style.foreground(Style.new(), :cyan)
      ti = [prompt: "> ", focused_style: style] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hi")
      frame = TextInput.view(ti)
      assert frame.cursor == nil
    end

    test "blurred_style applied to prompt and text when blurred" do
      style = Style.foreground(Style.new(), :bright_black)
      ti = [prompt: "> ", blurred_style: style] |> TextInput.init() |> TextInput.set_value("hi")
      frame = TextInput.view(ti)
      assert frame.content == Style.render(style, "> hi")
    end

    test "focused_style applied to text around cursor, cursor char reversed with style" do
      style = Style.foreground(Style.new(), :cyan)
      ti = [prompt: "", focused_style: style] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("abc")
      ti = %{ti | cursor: 1}
      frame = TextInput.view(ti)
      # "a" styled, "b" reversed+styled, "c" styled
      cursor_char = Style.render(Style.reverse(style), "b")
      assert frame.content == Style.render(style, "a") <> cursor_char <> Style.render(style, "c")
    end

    test "password mode with blurred input masks value" do
      ti = [prompt: "", echo_mode: :password] |> TextInput.init() |> TextInput.set_value("secret")
      frame = TextInput.view(ti)
      assert frame.content == "******"
    end

    test "password mode with custom echo_char and blurred input" do
      ti = [prompt: "", echo_mode: :password, echo_char: "•"] |> TextInput.init() |> TextInput.set_value("abc")
      frame = TextInput.view(ti)
      assert frame.content == "•••"
    end

    test "focused_style applied to prompt when focused + empty + placeholder, cursor char on first placeholder grapheme" do
      style = Style.foreground(Style.new(), :magenta)
      ti = [prompt: "> ", placeholder: "Pikachu", focused_style: style] |> TextInput.init() |> TextInput.focus()
      frame = TextInput.view(ti)
      dim_style = Style.foreground(Style.new(), :bright_black)
      cursor_char = Style.render(Style.reverse(style), "P")
      assert frame.content == Style.render(style, "> ") <> cursor_char <> Style.render(dim_style, "ikachu")
      assert frame.cursor == nil
    end

    test "blurred_style applied to prompt when blurred + empty + placeholder" do
      style = Style.foreground(Style.new(), :bright_black)
      ti = TextInput.init(prompt: "> ", placeholder: "Pikachu", blurred_style: style)
      frame = TextInput.view(ti)
      dim_style = Style.foreground(Style.new(), :bright_black)
      assert frame.content == Style.render(style, "> ") <> Style.render(dim_style, "Pikachu")
    end

    test "hidden mode cursor is nil" do
      ti = [prompt: "", cursor_mode: :hidden] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hi")
      frame = TextInput.view(ti)
      assert frame.cursor == nil
    end

    test "hidden mode content includes full value with no cursor char" do
      ti = [prompt: "", cursor_mode: :hidden] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hi")
      frame = TextInput.view(ti)
      assert frame.content == "hi"
    end

    test "hidden mode — focused + empty + placeholder content shows placeholder dimmed" do
      ti = [prompt: "", cursor_mode: :hidden, placeholder: "Pikachu"] |> TextInput.init() |> TextInput.focus()
      frame = TextInput.view(ti)
      dim_style = Style.foreground(Style.new(), :bright_black)
      assert frame.content == Style.render(dim_style, "Pikachu")
      assert frame.cursor == nil
    end

    test "blink off — cursor is nil" do
      ti = [prompt: "", placeholder: "Pikachu"] |> TextInput.init() |> TextInput.focus()
      ti = %{ti | cursor_visible: false}
      frame = TextInput.view(ti)
      assert frame.cursor == nil
    end

    test "blink off — content shows placeholder dimmed" do
      ti = [prompt: "", placeholder: "Pikachu"] |> TextInput.init() |> TextInput.focus()
      ti = %{ti | cursor_visible: false}
      frame = TextInput.view(ti)
      dim_style = Style.foreground(Style.new(), :bright_black)
      assert frame.content == Style.render(dim_style, "Pikachu")
    end

    test "static mode — frame.cursor nil, cursor char embedded in content" do
      ti = [prompt: "", cursor_mode: :static] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hi")
      frame = TextInput.view(ti)
      cursor_char = Style.render(Style.reverse(Style.new()), " ")
      assert frame.cursor == nil
      assert frame.content == "hi" <> cursor_char
    end

    test "blink mode — frame.cursor always nil" do
      ti = [prompt: "", cursor_mode: :blink] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hi")
      assert ti.cursor_visible == true
      frame = TextInput.view(ti)
      assert frame.cursor == nil
    end

    test "blink mode — content has cursor char when visible, plain when not" do
      ti = [prompt: "", cursor_mode: :blink] |> TextInput.init() |> TextInput.focus() |> TextInput.set_value("hi")
      frame_on = TextInput.view(ti)
      frame_off = TextInput.view(%{ti | cursor_visible: false})
      cursor_char = Style.render(Style.reverse(Style.new()), " ")
      assert frame_on.content == "hi" <> cursor_char
      assert frame_off.content == "hi"
    end
  end

  describe "blink_cmd/1" do
    test "returns a task cmd when cursor_mode is :blink" do
      ti = TextInput.init([])
      assert {:task, fun} = TextInput.blink_cmd(ti)
      assert is_function(fun, 0)
    end

    test "returns nil when cursor_mode is :static" do
      ti = TextInput.init(cursor_mode: :static)
      assert TextInput.blink_cmd(ti) == nil
    end

    test "returns nil when cursor_mode is :hidden" do
      ti = TextInput.init(cursor_mode: :hidden)
      assert TextInput.blink_cmd(ti) == nil
    end
  end

  describe "handle_blink/2" do
    test "matching tick toggles cursor_visible and re-arms" do
      ti = [] |> TextInput.init() |> TextInput.focus()
      assert ti.cursor_visible == true
      {ti2, cmd} = TextInput.handle_blink(ti, {:text_input_blink, ti.cursor_id})
      assert ti2.cursor_visible == false
      assert {:task, _} = cmd
    end

    test "second matching tick toggles cursor_visible back to true" do
      ti = [] |> TextInput.init() |> TextInput.focus()
      {ti2, _cmd} = TextInput.handle_blink(ti, {:text_input_blink, ti.cursor_id})
      {ti3, cmd} = TextInput.handle_blink(ti2, {:text_input_blink, ti2.cursor_id})
      assert ti3.cursor_visible == true
      assert {:task, _} = cmd
    end

    test "stale tick (wrong id) is ignored" do
      ti = [] |> TextInput.init() |> TextInput.focus()
      stale_id = ti.cursor_id + 1000
      {ti2, cmd} = TextInput.handle_blink(ti, {:text_input_blink, stale_id})
      assert ti2 == ti
      assert cmd == nil
    end

    test "non-matching message is ignored" do
      ti = TextInput.init([])
      {ti2, cmd} = TextInput.handle_blink(ti, :some_other_message)
      assert ti2 == ti
      assert cmd == nil
    end

    test "cursor_id rotates after each successful tick" do
      ti = TextInput.init([])
      {ti2, _} = TextInput.handle_blink(ti, {:text_input_blink, ti.cursor_id})
      assert ti2.cursor_id != ti.cursor_id
    end
  end

  describe "set_cursor_mode/2" do
    test "sets cursor_mode" do
      ti = TextInput.init([])
      ti2 = TextInput.set_cursor_mode(ti, :static)
      assert ti2.cursor_mode == :static
    end

    test "rotates cursor_id so in-flight blink tasks become stale" do
      ti = TextInput.init([])
      ti2 = TextInput.set_cursor_mode(ti, :hidden)
      assert ti2.cursor_id != ti.cursor_id
    end

    test "resets cursor_visible to true" do
      ti = TextInput.init([])
      {ti2, _} = TextInput.handle_blink(ti, {:text_input_blink, ti.cursor_id})
      assert ti2.cursor_visible == false
      ti3 = TextInput.set_cursor_mode(ti2, :static)
      assert ti3.cursor_visible == true
    end

    test "set to :blink — blink_cmd/1 returns a task cmd after mode change" do
      ti = TextInput.init(cursor_mode: :static)
      ti2 = TextInput.set_cursor_mode(ti, :blink)
      assert ti2.cursor_mode == :blink
      assert {:task, fun} = TextInput.blink_cmd(ti2)
      assert is_function(fun, 0)
    end
  end
end
