defmodule Tela.Key do
  @moduledoc """
  Represents a single parsed key event from the terminal.

  A `Tela.Key` struct is produced by `Tela.Input.parse/1` for every keystroke
  received from stdin. It is the value passed to `c:Tela.handle_event/2`.

  ## Fields

  - `:key` — the semantic key value (see `t:key/0`).
  - `:raw` — the raw bytes received from the terminal, useful for debugging.

  ## Key types

  Printable characters are represented as `{:char, string}`, for example
  `{:char, "a"}` or `{:char, "!"}`.

  Control characters use `{:ctrl, string}`, for example `{:ctrl, "c"}` for
  Ctrl+C or `{:ctrl, "s"}` for Ctrl+S. Note that some terminals send `0x08`
  (ctrl+h) instead of `0x7F` (DEL) for the physical Backspace key. Both are
  valid backspace inputs — `Tela.Component.TextInput` treats them identically.

  Alt/Meta characters use `{:alt, string}`, for example `{:alt, "b"}` for
  Alt+B.

  Function keys use `{:f, n}`, for example `{:f, 1}` for F1.

  All other recognised keys (arrows, enter, escape, tab, etc.) are atoms.

  Unrecognised byte sequences produce `:unknown`.
  """

  @typedoc """
  The semantic value of a key event.
  """
  @type key ::
          :up
          | :down
          | :left
          | :right
          | :enter
          | :escape
          | :backspace
          | :delete
          | :tab
          | :shift_tab
          | :home
          | :end
          | :page_up
          | :page_down
          | {:f, 1..12}
          | {:char, String.t()}
          | {:ctrl, String.t()}
          | {:alt, String.t()}
          | :unknown

  @typedoc """
  A parsed key event.
  """
  @type t :: %__MODULE__{
          key: key(),
          raw: binary()
        }

  defstruct [:key, :raw]
end
