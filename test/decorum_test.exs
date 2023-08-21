defmodule DecorumTest do
  use ExUnit.Case
  doctest Decorum

  describe "for_all" do
    test "takes 100 items from the generator" do
      Decorum.for_all(1..150, fn x -> x < 101 end)

      assert_raise RuntimeError, ~r/value: 100/, fn ->
        Decorum.for_all(1..150, fn x -> x < 100 end)
      end
    end
  end
end
