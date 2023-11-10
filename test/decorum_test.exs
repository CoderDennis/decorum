defmodule DecorumTest do
  use ExUnit.Case, async: true
  doctest Decorum

  alias Decorum.PRNG

  describe "check_all" do
    test "takes exactly 100 items from the generator" do
      # create a hardcoded prng with the values 1 to 150
      prng = PRNG.hardcoded(Enum.to_list(1..150))

      # ensure that the value 100 is used
      assert_raise ExUnit.AssertionError,
                   ~r/Assertion with < failed, both sides are exactly equal/,
                   fn ->
                     Decorum.check_all(Decorum.prng_values(), prng, fn x -> assert x < 100 end)
                   end

      # check that the value 101 is not used
      Decorum.check_all(Decorum.prng_values(), prng, fn x -> assert x < 101 end)
    end
  end

  describe "Enumerable" do
    test "a Decorum struct works with the Enum module" do
      Enum.take(Decorum.prng_values(), 10)
    end
  end

  describe "Generators" do
    test "map" do
      prng = PRNG.hardcoded(Enum.to_list(1..3))

      values =
        Decorum.map(Decorum.prng_values(), fn x -> x * 2 end)
        |> Decorum.stream(prng)
        |> Enum.take(3)

      assert values == [2, 4, 6]
    end

    test "property uniform_integer does not produce numbers greater than given max" do
      prng = PRNG.random()

      Decorum.check_all(Decorum.prng_values(), prng, fn max ->
        randomInt = Decorum.uniform_integer(max)
        assert randomInt |> Enum.take(10) |> Enum.all?(fn x -> x <= max end)
      end)
    end

    test "uniform_integer with max zero only produces zeros" do
      max_zero = Decorum.uniform_integer(0)
      assert max_zero |> Enum.take(10) |> Enum.all?(fn x -> x == 0 end)
    end

    test "uniform_integer with max 1 produces some zeros and some ones" do
      max_one = Decorum.uniform_integer(1) |> Enum.take(100) |> Enum.to_list()
      assert max_one |> Enum.any?(fn x -> x == 0 end)
      assert max_one |> Enum.any?(fn x -> x == 1 end)
    end

    test "integer with range from negative to positive produces some negative and some positive integers" do
      range = Decorum.integer(-1..1) |> Enum.take(100) |> Enum.to_list()

      assert range |> Enum.any?(fn x -> x > 0 end)
      assert range |> Enum.any?(fn x -> x < 0 end)
    end
  end

  describe "Shrinking" do
    test "an integer that is a multiple of 100 shrinks to 400 when asserting that it is less than 321" do
      prng = PRNG.random()

      assert_raise ExUnit.AssertionError,
                   ~r/left:  400/,
                   fn ->
                     0..9000//100
                     |> Decorum.integer()
                     |> Decorum.check_all(prng, fn x -> assert x < 321 end)
                   end
    end
  end
end
