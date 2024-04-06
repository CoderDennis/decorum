defmodule ShrinkingChallengeTest do
  use ExUnit.Case, async: true

  @moduledoc """
  See https://github.com/jlink/shrinking-challenge

  Implementing these tests to exercise the Decorum shrinker.
  """

  test "bound5" do
    %Decorum.PropertyError{value: value} =
      assert_raise Decorum.PropertyError,
                   fn ->
                     Decorum.integer(-32768..32767)
                     |> Decorum.list_of()
                     |> Decorum.filter(fn lst ->
                       sum(lst) < 256
                     end)
                     |> Decorum.list_of_length(5)
                     |> Decorum.check_all(fn lists ->
                       assert lists
                              |> Enum.concat()
                              |> sum() <
                                5 * 256
                     end)
                   end

    # assert that 3 of the lists are empty
    assert Enum.count(value, &(&1 == [])) == 3
  end

  @tag :skip
  test "difference 1" do
    %Decorum.PropertyError{value: value} =
      assert_raise Decorum.PropertyError,
                   fn ->
                     Decorum.zip(
                       Decorum.integer(0..1000),
                       Decorum.integer(0..1000)
                     )
                     |> Decorum.check_all(fn {x, y} ->
                       x < 10 or x != y
                     end)
                   end

    assert value == [10, 10]
  end

  test "large union list" do
    # takes 31.8 seconds with seed 804291
    %Decorum.PropertyError{value: value} =
      assert_raise Decorum.PropertyError,
                   fn ->
                     Decorum.integer(-4_294_967_296..4_294_967_295)
                     |> Decorum.list_of()
                     |> Decorum.list_of()
                     |> Decorum.check_all(fn lists ->
                       assert lists
                              |> Enum.concat()
                              |> Enum.uniq()
                              |> Enum.count() < 5
                     end)
                   end

    assert value == [[1, 2, 3, 4, 0]]
  end

  defp normalize(n) do
    n
    |> underflow
    |> overflow
  end

  defp sum(list) do
    list
    |> Enum.map(&normalize/1)
    |> Enum.reduce(0, &add/2)
  end

  defp add(a, b) do
    normalize(a + b)
  end

  defp overflow(n) do
    if n > 32767 do
      overflow(n - 65536)
    else
      n
    end
  end

  defp underflow(n) do
    if n < -32768 do
      underflow(n + 65536)
    else
      n
    end
  end
end
