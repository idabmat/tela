defmodule Tela.Component.SpinnerPropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Tela.Component.Spinner

  @presets [
    :line,
    :dot,
    :mini_dot,
    :jump,
    :pulse,
    :points,
    :globe,
    :moon,
    :monkey,
    :meter,
    :hamburger,
    :ellipsis
  ]

  defp preset_gen, do: StreamData.member_of(@presets)

  property "view/1 never crashes for any frame index" do
    check all(
            preset <- preset_gen(),
            frame <- StreamData.integer(0..1000)
          ) do
      spinner = %{Spinner.init(spinner: preset) | frame: frame}
      result = Spinner.view(spinner)
      assert %Tela.Frame{} = result
      assert is_binary(result.content)
      assert result.cursor == nil
    end
  end

  property "handle_tick/2 with matching id always advances frame within bounds" do
    check all(preset <- preset_gen()) do
      spinner = Spinner.init(spinner: preset)
      {new_spinner, cmd} = Spinner.handle_tick(spinner, {:spinner_tick, spinner.id})
      frame_count = length(spinner.frames)
      assert new_spinner.frame >= 0
      assert new_spinner.frame < frame_count
      assert {:task, _} = cmd
    end
  end

  property "handle_tick/2 with stale id never changes model" do
    check all(
            preset <- preset_gen(),
            stale_offset <- StreamData.positive_integer()
          ) do
      spinner = Spinner.init(spinner: preset)
      stale_id = spinner.id + stale_offset
      {new_spinner, cmd} = Spinner.handle_tick(spinner, {:spinner_tick, stale_id})
      assert new_spinner == spinner
      assert cmd == nil
    end
  end

  property "tick_cmd/1 always returns a {:task, fun} with a zero-arity function" do
    check all(preset <- preset_gen()) do
      spinner = Spinner.init(spinner: preset)
      assert {:task, fun} = Spinner.tick_cmd(spinner)
      assert is_function(fun, 0)
    end
  end
end
