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

  # test "random PRNG with the same seed generates the same value" do
  #   seed = ExUnit.configuration()[:seed]

  #   prng = PRNG.random(seed)
  #   {value1, _} = PRNG.next!(prng)

  #   prng = PRNG.random(seed)
  #   {value2, _} = PRNG.next!(prng)

  #   assert value1 == value2
  # end

  test "hardcoded PRNG replays the given history" do
    history = Enum.to_list(100..150)

    {values, _prng} = get_values(PRNG.hardcoded(history), 50)

    assert history == values
  end

  test "hardcoded PRNG raises EmptyHistoryError when empty" do
    history = [1]

    prng = PRNG.hardcoded(history)
    {1, prng} = PRNG.next!(prng)
    assert_raise Decorum.PRNG.EmptyHistoryError, fn -> PRNG.next!(prng) end
  end

  @spec get_values(prng :: PRNG.t(), count :: non_neg_integer()) :: {non_neg_integer(), PRNG.t()}
  def get_values(prng, count) do
    0..count
    |> Enum.reduce({[], prng}, fn _, {list, prng} ->
      {value, new_prng} = PRNG.next!(prng)
      {list ++ [value], new_prng}
    end)
  end
end
