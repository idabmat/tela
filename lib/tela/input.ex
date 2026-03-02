defmodule Tela.Input do
  @moduledoc """
  Parses raw terminal byte sequences into `Tela.Key` structs.

  OTP 28's raw terminal mode delivers keystrokes as raw bytes via
  `:io.get_chars/2`. This module is responsible for translating those bytes
  into structured `Tela.Key` values that applications can pattern-match on.

  ## Usage

      iex> Tela.Input.parse("a")
      [%Tela.Key{key: {:char, "a"}, raw: "a"}]

      iex> Tela.Input.parse("\\e[A")
      [%Tela.Key{key: :up, raw: "\\e[A"}]

      iex> Tela.Input.parse("\\e[A\\e[B")
      [%Tela.Key{key: :up, raw: "\\e[A"}, %Tela.Key{key: :down, raw: "\\e[B"}]

  ## Batched input

  Multiple keystrokes may arrive in a single `:io.get_chars/2` call — for
  example during rapid typing or paste. `parse/1` handles this correctly by
  consuming the binary recursively and returning one `Tela.Key` per keystroke.

  ## Unknown sequences

  Any byte sequence that does not match a known pattern produces a
  `Tela.Key` with `key: :unknown`. The raw bytes are preserved in the `:raw`
  field for debugging.
  """

  alias Tela.Key

  @doc """
  Parses a binary of raw terminal bytes into a list of `Tela.Key` structs.

  Returns an empty list for empty input. Unrecognised sequences produce a
  key with `key: :unknown`.

  ## Examples

      iex> Tela.Input.parse("")
      []

      iex> Tela.Input.parse("q")
      [%Tela.Key{key: {:char, "q"}, raw: "q"}]

      iex> Tela.Input.parse("\\r")
      [%Tela.Key{key: :enter, raw: "\\r"}]

      iex> Tela.Input.parse("\\e[A")
      [%Tela.Key{key: :up, raw: "\\e[A"}]

  """
  @spec parse(binary()) :: [Key.t()]
  def parse(binary) when is_binary(binary) do
    binary
    |> do_parse([])
    |> Enum.reverse()
  end

  defp do_parse("", acc), do: acc

  defp do_parse(<<?\r, rest::binary>>, acc), do: do_parse(rest, [key(:enter, "\r") | acc])

  defp do_parse(<<?\n, rest::binary>>, acc), do: do_parse(rest, [key(:enter, "\n") | acc])

  defp do_parse(<<?\t, rest::binary>>, acc), do: do_parse(rest, [key(:tab, "\t") | acc])

  # Backspace (DEL 0x7F)
  defp do_parse(<<0x7F, rest::binary>>, acc), do: do_parse(rest, [key(:backspace, <<0x7F>>) | acc])

  # Shift+Tab: ESC [ Z
  defp do_parse(<<?\e, ?[, ?Z, rest::binary>>, acc), do: do_parse(rest, [key(:shift_tab, "\e[Z") | acc])

  # Arrow keys: ESC [ A/B/C/D
  defp do_parse(<<?\e, ?[, ?A, rest::binary>>, acc), do: do_parse(rest, [key(:up, "\e[A") | acc])

  defp do_parse(<<?\e, ?[, ?B, rest::binary>>, acc), do: do_parse(rest, [key(:down, "\e[B") | acc])

  defp do_parse(<<?\e, ?[, ?C, rest::binary>>, acc), do: do_parse(rest, [key(:right, "\e[C") | acc])

  defp do_parse(<<?\e, ?[, ?D, rest::binary>>, acc), do: do_parse(rest, [key(:left, "\e[D") | acc])

  # Home: ESC [ H or ESC [ 1 ~
  defp do_parse(<<?\e, ?[, ?H, rest::binary>>, acc), do: do_parse(rest, [key(:home, "\e[H") | acc])

  defp do_parse(<<?\e, ?[, ?1, ?~, rest::binary>>, acc), do: do_parse(rest, [key(:home, "\e[1~") | acc])

  # End: ESC [ F or ESC [ 4 ~
  defp do_parse(<<?\e, ?[, ?F, rest::binary>>, acc), do: do_parse(rest, [key(:end, "\e[F") | acc])

  defp do_parse(<<?\e, ?[, ?4, ?~, rest::binary>>, acc), do: do_parse(rest, [key(:end, "\e[4~") | acc])

  # Delete: ESC [ 3 ~
  defp do_parse(<<?\e, ?[, ?3, ?~, rest::binary>>, acc), do: do_parse(rest, [key(:delete, "\e[3~") | acc])

  # Page Up: ESC [ 5 ~
  defp do_parse(<<?\e, ?[, ?5, ?~, rest::binary>>, acc), do: do_parse(rest, [key(:page_up, "\e[5~") | acc])

  # Page Down: ESC [ 6 ~
  defp do_parse(<<?\e, ?[, ?6, ?~, rest::binary>>, acc), do: do_parse(rest, [key(:page_down, "\e[6~") | acc])

  # Function keys F1-F4: ESC O P/Q/R/S
  defp do_parse(<<?\e, ?O, ?P, rest::binary>>, acc), do: do_parse(rest, [key({:f, 1}, "\eOP") | acc])

  defp do_parse(<<?\e, ?O, ?Q, rest::binary>>, acc), do: do_parse(rest, [key({:f, 2}, "\eOQ") | acc])

  defp do_parse(<<?\e, ?O, ?R, rest::binary>>, acc), do: do_parse(rest, [key({:f, 3}, "\eOR") | acc])

  defp do_parse(<<?\e, ?O, ?S, rest::binary>>, acc), do: do_parse(rest, [key({:f, 4}, "\eOS") | acc])

  # Function keys F5-F12: ESC [ N ~
  defp do_parse(<<?\e, ?[, ?1, ?5, ?~, rest::binary>>, acc), do: do_parse(rest, [key({:f, 5}, "\e[15~") | acc])

  defp do_parse(<<?\e, ?[, ?1, ?7, ?~, rest::binary>>, acc), do: do_parse(rest, [key({:f, 6}, "\e[17~") | acc])

  defp do_parse(<<?\e, ?[, ?1, ?8, ?~, rest::binary>>, acc), do: do_parse(rest, [key({:f, 7}, "\e[18~") | acc])

  defp do_parse(<<?\e, ?[, ?1, ?9, ?~, rest::binary>>, acc), do: do_parse(rest, [key({:f, 8}, "\e[19~") | acc])

  defp do_parse(<<?\e, ?[, ?2, ?0, ?~, rest::binary>>, acc), do: do_parse(rest, [key({:f, 9}, "\e[20~") | acc])

  defp do_parse(<<?\e, ?[, ?2, ?1, ?~, rest::binary>>, acc), do: do_parse(rest, [key({:f, 10}, "\e[21~") | acc])

  defp do_parse(<<?\e, ?[, ?2, ?3, ?~, rest::binary>>, acc), do: do_parse(rest, [key({:f, 11}, "\e[23~") | acc])

  defp do_parse(<<?\e, ?[, ?2, ?4, ?~, rest::binary>>, acc), do: do_parse(rest, [key({:f, 12}, "\e[24~") | acc])

  # Alt + printable letter: ESC <letter>
  defp do_parse(<<?\e, ch, rest::binary>>, acc) when ch >= 32 and ch <= 126 do
    raw = <<?\e, ch>>
    do_parse(rest, [key({:alt, <<ch>>}, raw) | acc])
  end

  # Bare escape: ESC with nothing following
  defp do_parse(<<?\e, rest::binary>>, acc), do: do_parse(rest, [key(:escape, "\e") | acc])

  # Control characters (0x01-0x1A, excluding already-handled \t \n \r \e)
  # Map byte to letter: 0x01 = ctrl+a, 0x02 = ctrl+b, ..., 0x1A = ctrl+z
  # Note: 0x08 = ctrl+h (BS byte). Some terminals send this for the physical
  # Backspace key instead of 0x7F (DEL). It is emitted as {:ctrl, "h"} here
  # and handled as backspace in Tela.Component.TextInput.
  defp do_parse(<<byte, rest::binary>>, acc)
       when byte >= 0x01 and byte <= 0x1A and byte != ?\t and byte != ?\n and byte != ?\r do
    letter = <<byte + ?a - 1>>
    do_parse(rest, [key({:ctrl, letter}, <<byte>>) | acc])
  end

  # Printable ASCII (0x20-0x7E)
  defp do_parse(<<byte, rest::binary>>, acc) when byte >= 0x20 and byte <= 0x7E do
    do_parse(rest, [key({:char, <<byte>>}, <<byte>>) | acc])
  end

  # Unknown
  defp do_parse(<<byte, rest::binary>>, acc), do: do_parse(rest, [key(:unknown, <<byte>>) | acc])

  defp key(k, raw), do: %Key{key: k, raw: raw}
end
