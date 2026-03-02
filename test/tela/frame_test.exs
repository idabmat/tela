defmodule Tela.FrameTest do
  use ExUnit.Case, async: true

  alias Tela.Frame

  describe "new/1" do
    test "returns a Frame with the given content and nil cursor" do
      frame = Frame.new("Hello")
      assert frame.content == "Hello"
      assert frame.cursor == nil
    end

    test "accepts an empty string" do
      frame = Frame.new("")
      assert frame.content == ""
      assert frame.cursor == nil
    end
  end

  describe "new/2" do
    test "returns a Frame with the given content and cursor" do
      frame = Frame.new("Hello", cursor: {0, 3, :block})
      assert frame.content == "Hello"
      assert frame.cursor == {0, 3, :block}
    end

    test "accepts :bar cursor shape" do
      frame = Frame.new("Hello", cursor: {1, 0, :bar})
      assert frame.cursor == {1, 0, :bar}
    end

    test "accepts :underline cursor shape" do
      frame = Frame.new("Hello", cursor: {0, 5, :underline})
      assert frame.cursor == {0, 5, :underline}
    end

    test "cursor: nil is equivalent to new/1" do
      assert Frame.new("Hello", cursor: nil) == Frame.new("Hello")
    end
  end

  describe "join/2" do
    test "joins two frames with default newline separator" do
      a = Frame.new("Line A")
      b = Frame.new("Line B")
      result = Frame.join([a, b])
      assert result.content == "Line A\nLine B"
    end

    test "joins three frames with default newline separator" do
      frames = [Frame.new("A"), Frame.new("B"), Frame.new("C")]
      result = Frame.join(frames)
      assert result.content == "A\nB\nC"
    end

    test "joins with a custom separator" do
      a = Frame.new("A")
      b = Frame.new("B")
      result = Frame.join([a, b], separator: "\n\n")
      assert result.content == "A\n\nB"
    end

    test "single frame returns its content unchanged" do
      frame = Frame.new("Only")
      result = Frame.join([frame])
      assert result.content == "Only"
    end

    test "cursor is nil when no frame has a cursor" do
      frames = [Frame.new("A"), Frame.new("B"), Frame.new("C")]
      result = Frame.join(frames)
      assert result.cursor == nil
    end

    test "takes cursor from the first frame that has one, no offset needed" do
      a = Frame.new("Line A", cursor: {0, 3, :block})
      b = Frame.new("Line B")
      result = Frame.join([a, b])
      assert result.cursor == {0, 3, :block}
    end

    test "adjusts cursor row by the line count of preceding frames" do
      # Frame A has 1 line ("Line A"), separator adds 1 line boundary,
      # so frame B's row 0 maps to row 1 in the joined content.
      a = Frame.new("Line A")
      b = Frame.new("Line B", cursor: {0, 2, :block})
      result = Frame.join([a, b])
      assert result.cursor == {1, 2, :block}
    end

    test "multi-line first frame: cursor row in second frame offset by first frame's line count" do
      # Frame A has 3 lines. Separator adds 1 boundary.
      # Frame B's row 0 → row 3 in joined output.
      a = Frame.new("A\nB\nC")
      b = Frame.new("D", cursor: {0, 0, :bar})
      result = Frame.join([a, b])
      assert result.cursor == {3, 0, :bar}
    end

    test "cursor in third frame is offset by both preceding frames and separators" do
      # Joined content: "A\nB\nC\nD" — D is at row 3 (0-indexed).
      # Frame A: 0 newlines. Separator "\n": 1 newline. Frame B "B\nC": 1 newline.
      # Separator "\n": 1 newline. Total before D: 3. Frame C row 0 → row 3.
      a = Frame.new("A")
      b = Frame.new("B\nC")
      c = Frame.new("D", cursor: {0, 1, :underline})
      result = Frame.join([a, b, c])
      assert result.cursor == {3, 1, :underline}
    end

    test "takes the first non-nil cursor, ignores subsequent ones" do
      a = Frame.new("A")
      b = Frame.new("B", cursor: {0, 0, :block})
      c = Frame.new("C", cursor: {0, 0, :bar})
      result = Frame.join([a, b, c])
      # b's cursor wins; c's cursor is ignored
      assert result.cursor == {1, 0, :block}
    end

    test "multi-line separator is counted correctly" do
      # separator: "\n\n" adds 2 newlines → 2 line boundaries between frames
      a = Frame.new("A")
      b = Frame.new("B", cursor: {0, 0, :block})
      result = Frame.join([a, b], separator: "\n\n")
      # "A" is 1 line, "\n\n" adds 2, so B starts at row 2 (0-indexed)
      assert result.cursor == {2, 0, :block}
    end

    test "col is preserved unchanged regardless of offset" do
      a = Frame.new("first\nsecond")
      b = Frame.new("third", cursor: {0, 7, :bar})
      result = Frame.join([a, b])
      {_row, col, _shape} = result.cursor
      assert col == 7
    end

    test "shape is preserved unchanged" do
      a = Frame.new("prefix")
      b = Frame.new("content", cursor: {0, 0, :underline})
      result = Frame.join([a, b])
      {_row, _col, shape} = result.cursor
      assert shape == :underline
    end

    test "empty frames are handled — zero lines still contribute separator" do
      # An empty-content frame has 1 line (the empty string itself).
      a = Frame.new("")
      b = Frame.new("B", cursor: {0, 1, :block})
      result = Frame.join([a, b])
      assert result.cursor == {1, 1, :block}
    end
  end
end
