defmodule HistoryTest do
  use ExUnit.Case, async: true

  alias Decorum.History

  test "shrink_int with the value 10 gives possible values [0, 1, 2, 3, 4, 8, 9]" do
    possible_values = History.shrink_int(10) |> Enum.sort()
    assert possible_values == [0, 1, 2, 3, 4, 8, 9]
  end

  test "shrink_int with max 32-bit value has 64 possible values" do
    count = History.shrink_int(Integer.pow(2, 32)) |> Enum.count()
    assert count == 64
  end

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
