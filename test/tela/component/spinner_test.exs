defmodule Tela.Component.SpinnerTest do
  use ExUnit.Case, async: true

  alias Tela.Component.Spinner
  alias Tela.Style

  describe "init/1" do
    test "defaults to :line preset with frame 0" do
      spinner = Spinner.init([])
      assert spinner.frames == ["|", "/", "-", "\\"]
      assert spinner.interval_ms == 100
      assert spinner.frame == 0
    end

    test "spinner: :line preset" do
      spinner = Spinner.init(spinner: :line)
      assert spinner.frames == ["|", "/", "-", "\\"]
      assert spinner.interval_ms == 100
    end

    test "spinner: :dot preset" do
      spinner = Spinner.init(spinner: :dot)
      assert spinner.frames == ["⣾ ", "⣽ ", "⣻ ", "⢿ ", "⡿ ", "⣟ ", "⣯ ", "⣷ "]
      assert spinner.interval_ms == 100
    end

    test "spinner: :mini_dot preset" do
      spinner = Spinner.init(spinner: :mini_dot)
      assert spinner.frames == ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
      assert spinner.interval_ms == 83
    end

    test "spinner: :jump preset" do
      spinner = Spinner.init(spinner: :jump)
      assert spinner.frames == ["⢄", "⢂", "⢁", "⡁", "⡈", "⡐", "⡠"]
      assert spinner.interval_ms == 100
    end

    test "spinner: :pulse preset" do
      spinner = Spinner.init(spinner: :pulse)
      assert spinner.frames == ["█", "▓", "▒", "░"]
      assert spinner.interval_ms == 125
    end

    test "spinner: :points preset" do
      spinner = Spinner.init(spinner: :points)
      assert spinner.frames == ["∙∙∙", "●∙∙", "∙●∙", "∙∙●"]
      assert spinner.interval_ms == 143
    end

    test "spinner: :globe preset" do
      spinner = Spinner.init(spinner: :globe)
      assert spinner.frames == ["🌍", "🌎", "🌏"]
      assert spinner.interval_ms == 250
    end

    test "spinner: :moon preset" do
      spinner = Spinner.init(spinner: :moon)
      assert spinner.frames == ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"]
      assert spinner.interval_ms == 125
    end

    test "spinner: :monkey preset" do
      spinner = Spinner.init(spinner: :monkey)
      assert spinner.frames == ["🙈", "🙉", "🙊"]
      assert spinner.interval_ms == 333
    end

    test "spinner: :meter preset" do
      spinner = Spinner.init(spinner: :meter)
      assert spinner.frames == ["▱▱▱", "▰▱▱", "▰▰▱", "▰▰▰", "▰▰▱", "▰▱▱", "▱▱▱"]
      assert spinner.interval_ms == 143
    end

    test "spinner: :hamburger preset" do
      spinner = Spinner.init(spinner: :hamburger)
      assert spinner.frames == ["☱", "☲", "☴", "☲"]
      assert spinner.interval_ms == 333
    end

    test "spinner: :ellipsis preset" do
      spinner = Spinner.init(spinner: :ellipsis)
      assert spinner.frames == ["   ", ".  ", ".. ", "..."]
      assert spinner.interval_ms == 333
    end

    test "accepts custom {frames, interval_ms} tuple" do
      spinner = Spinner.init(spinner: {["a", "b", "c"], 50})
      assert spinner.frames == ["a", "b", "c"]
      assert spinner.interval_ms == 50
      assert spinner.frame == 0
    end

    test "raises ArgumentError for unknown preset atom" do
      assert_raise ArgumentError, ~r/unknown spinner/, fn ->
        Spinner.init(spinner: :nonexistent)
      end
    end

    test "assigns a unique integer id" do
      s1 = Spinner.init([])
      s2 = Spinner.init([])
      assert is_integer(s1.id)
      assert is_integer(s2.id)
      assert s1.id != s2.id
    end

    test "accepts style: option" do
      style = Style.foreground(Style.new(), :cyan)
      spinner = Spinner.init(style: style)
      assert spinner.style == style
    end

    test "defaults style to Tela.Style.new()" do
      spinner = Spinner.init([])
      assert spinner.style == Style.new()
    end
  end

  describe "view/1" do
    test "returns a Frame with cursor nil (display-only component)" do
      spinner = Spinner.init(spinner: :line)
      frame = Spinner.view(spinner)
      assert %Tela.Frame{} = frame
      assert frame.cursor == nil
    end

    test "returns the current frame (frame 0) as content when no style" do
      spinner = Spinner.init(spinner: :line)
      assert Spinner.view(spinner).content == "|"
    end

    test "returns correct frame after advancing" do
      spinner = %{Spinner.init(spinner: :line) | frame: 2}
      assert Spinner.view(spinner).content == "-"
    end

    test "applies configured style" do
      style = Style.foreground(Style.new(), :cyan)
      spinner = Spinner.init(spinner: :line, style: style)
      assert Spinner.view(spinner).content == Style.render(style, "|")
    end

    test "returns empty string content for out-of-bounds frame" do
      spinner = %{Spinner.init(spinner: :line) | frame: 999}
      assert Spinner.view(spinner).content == ""
    end
  end

  describe "tick_cmd/1" do
    test "returns a {:task, fun} tuple" do
      spinner = Spinner.init([])
      assert {:task, fun} = Spinner.tick_cmd(spinner)
      assert is_function(fun, 0)
    end

    test "executing the task returns {:spinner_tick, id}" do
      spinner = Spinner.init([])
      {:task, fun} = Spinner.tick_cmd(spinner)
      assert fun.() == {:spinner_tick, spinner.id}
    end
  end

  describe "handle_tick/2" do
    test "matching tick advances frame and returns new tick cmd" do
      spinner = Spinner.init(spinner: :line)
      {new_spinner, cmd} = Spinner.handle_tick(spinner, {:spinner_tick, spinner.id})
      assert new_spinner.frame == 1
      assert {:task, _} = cmd
    end

    test "id changes after each tick" do
      spinner = Spinner.init(spinner: :line)
      {new_spinner, _cmd} = Spinner.handle_tick(spinner, {:spinner_tick, spinner.id})
      assert new_spinner.id != spinner.id
    end

    test "new tick cmd carries new id" do
      spinner = Spinner.init(spinner: :line)
      {new_spinner, cmd} = Spinner.handle_tick(spinner, {:spinner_tick, spinner.id})
      {:task, fun} = cmd
      assert fun.() == {:spinner_tick, new_spinner.id}
    end

    test "wraps from last frame back to 0" do
      spinner = Spinner.init(spinner: :pulse)
      spinner = %{spinner | frame: 3}
      {new_spinner, _cmd} = Spinner.handle_tick(spinner, {:spinner_tick, spinner.id})
      assert new_spinner.frame == 0
    end

    test "ignores tick with stale id" do
      spinner = Spinner.init([])
      stale_id = spinner.id + 999
      {new_spinner, cmd} = Spinner.handle_tick(spinner, {:spinner_tick, stale_id})
      assert new_spinner == spinner
      assert cmd == nil
    end

    test "ignores non-tick messages" do
      spinner = Spinner.init([])
      {new_spinner, cmd} = Spinner.handle_tick(spinner, :some_other_message)
      assert new_spinner == spinner
      assert cmd == nil
    end

    test "ignores {:task_result, _} messages" do
      spinner = Spinner.init([])
      {new_spinner, cmd} = Spinner.handle_tick(spinner, {:task_result, :whatever})
      assert new_spinner == spinner
      assert cmd == nil
    end
  end

  describe "handle_event/2" do
    test "ignores all key events and returns {model, nil}" do
      spinner = Spinner.init([])

      keys = [
        %Tela.Key{key: {:char, "a"}},
        %Tela.Key{key: :enter},
        %Tela.Key{key: :up},
        %Tela.Key{key: {:ctrl, "c"}}
      ]

      for key <- keys do
        assert {^spinner, nil} = Spinner.handle_event(spinner, key)
      end
    end
  end
end
