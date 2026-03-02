defmodule Tela.RuntimeTest do
  use ExUnit.Case, async: true

  alias Tela.Input
  alias Tela.Key
  alias Tela.Runtime

  # A minimal Tela implementation used to drive process_keys/3 tests.
  # Model is a list of atoms recording which keys were handled, so tests can
  # assert whether handle_event was called for a given key.
  #
  # Key semantics:
  #   "q"     → :quit
  #   "t"     → {:task, fn -> :task_done end}
  #   anything else → nil

  defmodule Stub do
    @moduledoc false
    @behaviour Tela

    @impl Tela
    def init(_args), do: {[], nil}

    @impl Tela
    def handle_event(model, %Key{key: {:char, "q"}}), do: {[:q | model], :quit}

    def handle_event(model, %Key{key: {:char, "t"}}), do: {[:t | model], {:task, fn -> :task_done end}}

    def handle_event(model, %Key{key: {:char, k}}), do: {[String.to_atom(k) | model], nil}
    def handle_event(model, _key), do: {model, nil}

    @impl Tela
    def handle_info(model, _msg), do: {model, nil}

    @impl Tela
    def view(model), do: Tela.Frame.new(Enum.join(model, ","))
  end

  # Build a Key struct for a plain character.
  defp key(char), do: %Key{key: {:char, char}, raw: char}

  describe "process_keys/3 — :cont result" do
    test "returns :cont when all keys return nil" do
      keys = [key("a"), key("b"), key("c")]
      {result, _model, _cmds} = Runtime.process_keys(Stub, keys, [])
      assert result == :cont
    end

    test "accumulates model changes across all keys" do
      keys = [key("a"), key("b"), key("c")]
      {_result, model, _cmds} = Runtime.process_keys(Stub, keys, [])
      # handle_event prepends, so order is reversed
      assert model == [:c, :b, :a]
    end

    test "returns nil cmds when all keys return nil" do
      keys = [key("a"), key("b")]
      {_result, _model, cmds} = Runtime.process_keys(Stub, keys, [])
      assert cmds == [nil, nil]
    end

    test "includes task cmd in returned cmds" do
      keys = [key("t")]
      {result, _model, cmds} = Runtime.process_keys(Stub, keys, [])
      assert result == :cont
      assert [{:task, _fun}] = cmds
    end

    test "returns :cont for an empty key list" do
      {result, model, cmds} = Runtime.process_keys(Stub, [], [])
      assert result == :cont
      assert model == []
      assert cmds == []
    end
  end

  describe "process_keys/3 — :quit short-circuits" do
    test "returns :quit when the only key quits" do
      {result, _model, _cmds} = Runtime.process_keys(Stub, [key("q")], [])
      assert result == :quit
    end

    test "returns :quit when the last key quits" do
      keys = [key("a"), key("b"), key("q")]
      {result, _model, _cmds} = Runtime.process_keys(Stub, keys, [])
      assert result == :quit
    end

    test "does not call handle_event for keys after a quit" do
      # key "q" at position 1 should quit; key "a" at position 2 must not run.
      # If "a" ran, it would prepend :a onto the model.
      keys = [key("q"), key("a")]
      {result, model, _cmds} = Runtime.process_keys(Stub, keys, [])
      assert result == :quit
      # model should contain :q but NOT :a
      assert :q in model
      refute :a in model
    end

    test "does not call handle_event for any keys after quit in a long batch" do
      keys = [key("a"), key("q"), key("b"), key("c")]
      {result, model, _cmds} = Runtime.process_keys(Stub, keys, [])
      assert result == :quit
      assert :a in model
      assert :q in model
      refute :b in model
      refute :c in model
    end

    test "cmds from keys before quit are returned, cmds after are not" do
      # "a" → nil, "q" → :quit. Only the cmd for "a" is returned; :quit is
      # stripped — it is communicated via the {:quit, ...} tag, not the cmds list.
      keys = [key("a"), key("q"), key("b")]
      {_result, _model, cmds} = Runtime.process_keys(Stub, keys, [])
      assert cmds == [nil]
    end

    test ":quit is never present in the returned cmds list" do
      keys = [key("a"), key("q"), key("b")]
      {_result, _model, cmds} = Runtime.process_keys(Stub, keys, [])
      refute :quit in cmds
    end
  end

  describe "Input.parse/1 → process_keys/3 contract" do
    test "raw bytes for a non-quit key produce :cont with updated model" do
      # "a" as a raw byte → parse → one {:char, "a"} key → handle_event appends :a
      {result, model, _cmds} = Runtime.process_keys(Stub, Input.parse("a"), [])
      assert result == :cont
      assert :a in model
    end

    test "raw bytes for quit produce :quit with model updated up to quit" do
      # "aq" → parse → [{:char, "a"}, {:char, "q"}] → :a processed, then quit.
      # cmds contains only the cmd from "a" (nil); :quit is stripped from cmds.
      {result, model, cmds} = Runtime.process_keys(Stub, Input.parse("aq"), [])
      assert result == :quit
      assert :a in model
      assert :q in model
      assert cmds == [nil]
    end

    test "raw bytes after quit are not processed" do
      # "qb" → parse → [{:char, "q"}, {:char, "b"}] → quit short-circuits before "b"
      {result, model, _cmds} = Runtime.process_keys(Stub, Input.parse("qb"), [])
      assert result == :quit
      refute :b in model
    end
  end
end
