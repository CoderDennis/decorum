defmodule DecorumTest do
  use ExUnit.Case, async: true
  doctest Decorum

  alias Decorum.PRNG

  require Integer

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

    test "zip with two constant generators produces a tuple of values" do
      values =
        Decorum.zip(Decorum.constant(:a), Decorum.constant(:b))
        |> Enum.take(2)

      assert values == [{:a, :b}, {:a, :b}]
    end

    test "zip with a list of constant generators produces a tuple of values in order" do
      values =
        [:a, :b, :c]
        |> Enum.map(fn v -> Decorum.constant(v) end)
        |> Decorum.zip()
        |> Enum.take(1)
        |> List.first()

      assert values == {:a, :b, :c}
    end

    test "property uniform_integer does not produce numbers greater than given max" do
      Decorum.check_all(Decorum.prng_values(), fn max ->
        random_int = Decorum.uniform_integer(max)
        assert random_int |> Enum.take(10) |> Enum.all?(fn x -> x <= max end)
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

    test "filter is_even with hardcoded values 1 to 5 returns 2 and 4" do
      prng = PRNG.hardcoded(Enum.to_list(1..5))

      values =
        Decorum.prng_values()
        |> Decorum.filter(&Integer.is_even/1)
        |> Decorum.stream(prng)
        |> Stream.take(2)
        |> Enum.to_list()

      assert values == [2, 4]
    end
  end

  describe "Shrinking" do
    test "an integer that is a multiple of 100 shrinks to 400 when asserting that it is less than 321" do
      assert_raise Decorum.PropertyError,
                   ~r/^400/,
                   fn ->
                     0..9000//100
                     |> Decorum.integer()
                     |> Decorum.check_all(fn x -> assert x < 321 end)
                   end
    end

    test "a list of integers shrinks to [1,0] when asserting that the list is sorted" do
      assert_raise Decorum.PropertyError,
                   ~r/^\[1, 0\]/,
                   fn ->
                     Decorum.uniform_integer(50_000)
                     |> Decorum.list_of()
                     |> Decorum.check_all(fn lst -> assert lst == Enum.sort(lst) end)
                   end
    end
  end
end
