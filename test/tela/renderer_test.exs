defmodule Tela.RendererTest do
  use ExUnit.Case, async: true

  alias Tela.Renderer

  # Resolve iodata to a plain binary for easier assertions.
  defp render(prev, next), do: prev |> Renderer.diff(next) |> IO.iodata_to_binary()

  describe "diff/2 — first render (empty previous frame)" do
    test "clears the screen and moves to home on first render" do
      output = render([], ["Hello"])
      assert output =~ "\e[2J\e[H"
    end

    test "positions the single line at row 1 with correct structure" do
      output = render([], ["Hello"])
      assert output =~ "\e[1;1HHello\e[K"
    end

    test "positions each line at the correct row on first render" do
      output = render([], ["Line 1", "Line 2", "Line 3"])
      assert output =~ "\e[1;1HLine 1\e[K"
      assert output =~ "\e[2;1HLine 2\e[K"
      assert output =~ "\e[3;1HLine 3\e[K"
    end
  end

  describe "diff/2 — no change" do
    test "produces no output when prev and next are identical" do
      lines = ["Hello", "World"]
      output = render(lines, lines)
      assert output == ""
    end

    test "produces no output for a single identical line" do
      output = render(["Same"], ["Same"])
      assert output == ""
    end
  end

  describe "diff/2 — single line changed" do
    test "emits cursor-move, new content, and line-clear in order" do
      # Line at index 1 → row 2
      output = render(["Unchanged", "Old"], ["Unchanged", "New"])
      assert output =~ "\e[2;1HNew\e[K"
    end

    test "does not include cursor move for unchanged first line" do
      output = render(["Unchanged", "Old"], ["Unchanged", "New"])
      refute output =~ "\e[1;1H"
    end

    test "first line changed emits cursor-move at row 1" do
      output = render(["Old", "Unchanged"], ["New", "Unchanged"])
      assert output =~ "\e[1;1HNew\e[K"
    end
  end

  describe "diff/2 — next frame is shorter than previous" do
    test "emits cursor-move and line-clear for the removed line, no content" do
      # Prev had 2 lines, next has 1 — row 2 must be cleared with no content
      output = render(["Line 1", "Line 2"], ["Line 1"])
      assert output =~ "\e[2;1H\e[K"
      refute output =~ "Line 2"
    end
  end

  describe "diff/2 — next frame is longer than previous" do
    test "emits cursor-move, new content, and line-clear for the added line" do
      output = render(["Line 1"], ["Line 1", "Line 2"])
      assert output =~ "\e[2;1HLine 2\e[K"
    end
  end

  describe "diff/2 — multiple lines changed" do
    test "emits cursor-move and new content for every changed line" do
      output = render(["A", "B", "C"], ["X", "Y", "Z"])
      assert output =~ "\e[1;1HX\e[K"
      assert output =~ "\e[2;1HY\e[K"
      assert output =~ "\e[3;1HZ\e[K"
    end

    test "emits only changed lines when frame is partially different" do
      output = render(["A", "B", "C"], ["A", "Y", "C"])
      refute output =~ "\e[1;1H"
      assert output =~ "\e[2;1HY\e[K"
      refute output =~ "\e[3;1H"
    end
  end

  describe "diff/2 — cursor parking" do
    test "parks cursor below the last line after first render" do
      # 2 lines → cursor parked at row 3
      output = render([], ["Line 1", "Line 2"])
      assert output =~ "\e[3;1H"
    end

    test "parks cursor below the last line after an update" do
      # 3 lines, one changed → cursor parked at row 4
      output = render(["A", "B", "C"], ["A", "X", "C"])
      assert output =~ "\e[4;1H"
    end

    test "parks cursor at row 1 when next frame is empty" do
      output = render([], [])
      assert output =~ "\e[1;1H"
    end
  end
end
