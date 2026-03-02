defmodule Tela.RendererPropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Tela.Renderer

  # Resolve iodata to a plain binary for easier assertions.
  defp render(prev, next), do: prev |> Renderer.diff(next) |> IO.iodata_to_binary()

  describe "diff/2 — no crash on arbitrary input" do
    property "never raises for any list of strings" do
      check all(
              prev <- list_of(string(:printable)),
              next <- list_of(string(:printable))
            ) do
        result = Renderer.diff(prev, next)
        assert is_binary(IO.iodata_to_binary(result))
      end
    end
  end

  describe "diff/2 — idempotence" do
    property "identical prev and next always produce no output" do
      # min_length: 1 excludes the first-render path (prev == []), which
      # intentionally emits a full clear even when next is also empty.
      check all(lines <- list_of(string(:printable), min_length: 1)) do
        assert render(lines, lines) == ""
      end
    end
  end

  describe "diff/2 — first render coverage" do
    property "every line is positioned at its correct row with cursor-move and line-clear" do
      check all(lines <- list_of(string(:printable), min_length: 1)) do
        output = render([], lines)

        lines
        |> Enum.with_index(1)
        |> Enum.each(fn {line, row} ->
          assert String.contains?(output, "\e[#{row};1H#{line}\e[K")
        end)
      end
    end
  end
end
