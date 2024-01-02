defmodule PrngTest do
  use ExUnit.Case, async: true

  alias Decorum.Prng

  test "random Prng preserves history" do
    {values, prng} = get_values(Prng.random(), 10)

    history = Prng.get_history(prng)

    assert values == history
  end

  test "random Prng generates different values" do
    prng = Prng.random()

    {value1, prng} = Prng.next!(prng)
    {value2, _prng} = Prng.next!(prng)

    assert value1 != value2
  end

  test "hardcoded Prng replays the given history" do
    history = Enum.to_list(101..150)

    {values, _prng} = get_values(Prng.hardcoded(history), 50)

    assert history == values
  end

  test "hardcoded Prng raises EmptyHistoryError when empty" do
    history = [1]

    prng = Prng.hardcoded(history)
    {1, prng} = Prng.next!(prng)
    assert_raise Decorum.Prng.EmptyHistoryError, fn -> Prng.next!(prng) end
  end

  test "hardcoded Prng keeps track of the history it uses" do
    history = Enum.to_list(50..70)

    {values, prng} = get_values(Prng.hardcoded(history), 10)

    assert Prng.get_history(prng) == values
  end

  @spec get_values(prng :: Prng.t(), count :: non_neg_integer()) :: {non_neg_integer(), Prng.t()}
  def get_values(prng, count) do
    1..count
    |> Enum.reduce({[], prng}, fn _, {list, prng} ->
      {value, new_prng} = Prng.next!(prng)
      {list ++ [value], new_prng}
    end)
  end
end
