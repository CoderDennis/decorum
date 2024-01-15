defmodule HistoryTest do
  use ExUnit.Case, async: true

  alias Decorum.History

  test "property shrink_int produces 0 as the first value" do
    Decorum.check_all(Decorum.integer(1..Integer.pow(2, 32)), fn x ->
      first_value = History.shrink_int(x) |> Enum.at(0)
      assert first_value == 0
    end)
  end

  test "shrink history does not contain the original history" do
    possible_histories = History.shrink([2, 2, 2]) |> Enum.to_list()
    assert Enum.member?(possible_histories, [2, 2, 2]) == false
  end

  test "shrink [2, 2, 2] will contain [2, 0, 2]" do
    possible_histories = History.shrink([2, 2, 2]) |> Enum.to_list()
    assert Enum.member?(possible_histories, [2, 0, 2])
  end
end
