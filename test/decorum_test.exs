defmodule DecorumTest do
  use ExUnit.Case
  doctest Decorum

  describe "check_all" do
    test "takes exactly 100 items from the generator" do
      Decorum.check_all(1..150, fn x -> assert x < 101 end)

      assert_raise ExUnit.AssertionError,
                   ~r/Assertion with < failed, both sides are exactly equal/,
                   fn ->
                     Decorum.check_all(1..150, fn x -> assert x < 100 end)
                   end
    end
  end
end
