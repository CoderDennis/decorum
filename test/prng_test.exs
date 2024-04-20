defmodule PRNGTest do
  use ExUnit.Case, async: true

  alias Decorum.PRNG

  test "random PRNG preserves history" do
    {values, prng} = get_values(PRNG.random(), 10)

    history = PRNG.get_history(prng)

    assert values == history
  end

  test "random PRNG generates different values" do
    prng = PRNG.random()

    {value1, prng} = PRNG.next!(prng)
    {value2, _prng} = PRNG.next!(prng)

    assert value1 != value2
  end

  test "hardcoded PRNG replays the given history" do
    history = Enum.to_list(101..150)

    {values, _prng} = get_values(PRNG.hardcoded(history), 50)

    assert history == values
  end

  test "hardcoded PRNG raises EmptyHistoryError when empty" do
    history = [1]

    prng = PRNG.hardcoded(history)
    {1, prng} = PRNG.next!(prng)
    assert_raise Decorum.EmptyHistoryError, fn -> PRNG.next!(prng) end
  end

  test "hardcoded PRNG keeps track of the history it uses" do
    history = Enum.to_list(50..70)

    {values, prng} = get_values(PRNG.hardcoded(history), 10)

    assert PRNG.get_history(prng) == values
  end

  @spec get_values(prng :: PRNG.t(), count :: non_neg_integer()) :: {non_neg_integer(), PRNG.t()}
  def get_values(prng, count) do
    1..count
    |> Enum.reduce({[], prng}, fn _, {list, prng} ->
      {value, new_prng} = PRNG.next!(prng)
      {list ++ [value], new_prng}
    end)
  end
end
