defmodule PRNGTest do
  use ExUnit.Case

  test "random PRNG preserves history" do
    {values, prng} =
      1..10
      |> Enum.reduce({[], PRNG.random(ExUnit.configuration()[:seed])}, fn _, {list, prng} ->
        {value, new_prng} = PRNG.next(prng)
        {list ++ [value], new_prng}
      end)

    history = PRNG.get_history(prng)

    assert values == history
  end

  test "random PRNG generates different values" do
    prng = PRNG.random(ExUnit.configuration()[:seed])

    {value1, prng} = PRNG.next(prng)
    {value2, _prng} = PRNG.next(prng)

    assert value1 != value2
  end

  test "random PRNG with the same seed generates the same value" do
    seed = 5

    prng = PRNG.random(seed)
    {value1, _} = PRNG.next(prng)

    prng = PRNG.random(seed)
    {value2, _} = PRNG.next(prng)

    assert value1 == value2
  end

  test "hardcoded PRNG replays the given history" do
    history = Enum.to_list(101..150)

    {values, _prng} =
      1..50
      |> Enum.reduce({[], PRNG.hardcoded(history)}, fn _, {list, prng} ->
        {value, new_prng} = PRNG.next(prng)
        {list ++ [value], new_prng}
      end)

    assert history == values
  end

  test "hardcoded PRNG returns :error when empty" do
    history = [1]

    prng = PRNG.hardcoded(history)
    {1, prng} = PRNG.next(prng)
    {:error, _} = PRNG.next(prng)
  end
end
