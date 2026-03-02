defmodule Tela.InputTest do
  use ExUnit.Case, async: true

  alias Tela.Input

  # Helper: parse and return just the key field(s) for brevity.
  defp keys(binary), do: binary |> Input.parse() |> Enum.map(& &1.key)

  # Helper: parse a single key event and return the full struct.
  defp one(binary) do
    [key] = Input.parse(binary)
    key
  end

  describe "parse/1 — empty input" do
    test "empty binary returns empty list" do
      assert Input.parse("") == []
    end
  end

  describe "parse/1 — printable ASCII characters" do
    test "single lowercase letter" do
      assert keys("a") == [{:char, "a"}]
    end

    test "single uppercase letter" do
      assert keys("Z") == [{:char, "Z"}]
    end

    test "digit" do
      assert keys("5") == [{:char, "5"}]
    end

    test "space" do
      assert keys(" ") == [{:char, " "}]
    end

    test "punctuation" do
      assert keys("!") == [{:char, "!"}]
    end

    test "multiple printable characters produce one key per character" do
      assert keys("hi") == [{:char, "h"}, {:char, "i"}]
    end

    test "raw field contains the original byte" do
      assert one("q").raw == "q"
    end
  end

  describe "parse/1 — control characters" do
    test "enter (carriage return \\r)" do
      assert keys("\r") == [:enter]
    end

    test "enter (newline \\n)" do
      assert keys("\n") == [:enter]
    end

    test "tab" do
      assert keys("\t") == [:tab]
    end

    test "backspace (DEL, 0x7F)" do
      assert keys("\x7f") == [:backspace]
    end

    test "ctrl+c (ETX, 0x03)" do
      assert keys("\x03") == [{:ctrl, "c"}]
    end

    test "ctrl+a (SOH, 0x01)" do
      assert keys("\x01") == [{:ctrl, "a"}]
    end

    test "ctrl+s (0x13)" do
      assert keys("\x13") == [{:ctrl, "s"}]
    end

    test "ctrl+u (0x15)" do
      assert keys("\x15") == [{:ctrl, "u"}]
    end

    test "ctrl+w (0x17)" do
      assert keys("\x17") == [{:ctrl, "w"}]
    end

    test "raw field contains the original byte for ctrl keys" do
      assert one("\x03").raw == "\x03"
    end
  end

  describe "parse/1 — escape alone" do
    test "bare escape (0x1B) with nothing following" do
      assert keys("\x1b") == [:escape]
    end
  end

  describe "parse/1 — arrow keys (ANSI CSI sequences)" do
    test "up arrow (ESC [ A)" do
      assert keys("\e[A") == [:up]
    end

    test "down arrow (ESC [ B)" do
      assert keys("\e[B") == [:down]
    end

    test "right arrow (ESC [ C)" do
      assert keys("\e[C") == [:right]
    end

    test "left arrow (ESC [ D)" do
      assert keys("\e[D") == [:left]
    end

    test "raw field contains the full escape sequence" do
      assert one("\e[A").raw == "\e[A"
    end
  end

  describe "parse/1 — navigation keys" do
    test "shift+tab (ESC [ Z)" do
      assert keys("\e[Z") == [:shift_tab]
    end

    test "home (ESC [ H)" do
      assert keys("\e[H") == [:home]
    end

    test "home (ESC [ 1 ~)" do
      assert keys("\e[1~") == [:home]
    end

    test "end (ESC [ F)" do
      assert keys("\e[F") == [:end]
    end

    test "end (ESC [ 4 ~)" do
      assert keys("\e[4~") == [:end]
    end

    test "delete (ESC [ 3 ~)" do
      assert keys("\e[3~") == [:delete]
    end

    test "page up (ESC [ 5 ~)" do
      assert keys("\e[5~") == [:page_up]
    end

    test "page down (ESC [ 6 ~)" do
      assert keys("\e[6~") == [:page_down]
    end
  end

  describe "parse/1 — function keys" do
    test "F1 (ESC O P)" do
      assert keys("\eOP") == [{:f, 1}]
    end

    test "F2 (ESC O Q)" do
      assert keys("\eOQ") == [{:f, 2}]
    end

    test "F3 (ESC O R)" do
      assert keys("\eOR") == [{:f, 3}]
    end

    test "F4 (ESC O S)" do
      assert keys("\eOS") == [{:f, 4}]
    end

    test "F5 (ESC [ 15 ~)" do
      assert keys("\e[15~") == [{:f, 5}]
    end

    test "F6 (ESC [ 17 ~)" do
      assert keys("\e[17~") == [{:f, 6}]
    end

    test "F7 (ESC [ 18 ~)" do
      assert keys("\e[18~") == [{:f, 7}]
    end

    test "F8 (ESC [ 19 ~)" do
      assert keys("\e[19~") == [{:f, 8}]
    end

    test "F9 (ESC [ 20 ~)" do
      assert keys("\e[20~") == [{:f, 9}]
    end

    test "F10 (ESC [ 21 ~)" do
      assert keys("\e[21~") == [{:f, 10}]
    end

    test "F11 (ESC [ 23 ~)" do
      assert keys("\e[23~") == [{:f, 11}]
    end

    test "F12 (ESC [ 24 ~)" do
      assert keys("\e[24~") == [{:f, 12}]
    end
  end

  describe "parse/1 — alt/meta keys" do
    test "alt+b (ESC b)" do
      assert keys("\eb") == [{:alt, "b"}]
    end

    test "alt+f (ESC f)" do
      assert keys("\ef") == [{:alt, "f"}]
    end

    test "alt+a (ESC a)" do
      assert keys("\ea") == [{:alt, "a"}]
    end

    test "alt+z (ESC z)" do
      assert keys("\ez") == [{:alt, "z"}]
    end

    test "alt+0 (ESC 0)" do
      assert keys("\e0") == [{:alt, "0"}]
    end

    test "alt+9 (ESC 9)" do
      assert keys("\e9") == [{:alt, "9"}]
    end

    test "alt+! (ESC !)" do
      assert keys("\e!") == [{:alt, "!"}]
    end

    test "alt key raw field contains the full ESC + char sequence" do
      assert one("\ea").raw == "\ea"
    end
  end

  describe "parse/1 — batched input" do
    test "two arrow keys in one chunk produce two key events" do
      assert keys("\e[A\e[B") == [:up, :down]
    end

    test "printable characters mixed with escape sequences" do
      assert keys("a\e[Ab") == [{:char, "a"}, :up, {:char, "b"}]
    end

    test "three printable characters" do
      assert keys("abc") == [{:char, "a"}, {:char, "b"}, {:char, "c"}]
    end
  end

  describe "parse/1 — unknown sequences" do
    test "unrecognised byte returns :unknown" do
      assert keys(<<0xFF>>) == [:unknown]
    end

    test "raw field contains the unrecognised byte" do
      assert one(<<0xFF>>).raw == <<0xFF>>
    end
  end
end
