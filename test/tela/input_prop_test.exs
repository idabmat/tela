defmodule Tela.InputPropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Tela.Input

  describe "parse/1 — no crash on arbitrary input" do
    property "never raises on any binary" do
      check all(bin <- binary()) do
        result = Input.parse(bin)
        assert is_list(result)
      end
    end
  end

  describe "parse/1 — non-empty input produces non-empty output" do
    property "at least one key is produced for any non-empty binary" do
      check all(bin <- binary(min_length: 1)) do
        assert Input.parse(bin) != []
      end
    end
  end

  describe "parse/1 — raw field preservation" do
    property "concatenation of all raw fields equals the original binary" do
      check all(bin <- binary()) do
        keys = Input.parse(bin)
        reconstructed = keys |> Enum.map(& &1.raw) |> IO.iodata_to_binary()
        assert reconstructed == bin
      end
    end
  end
end
