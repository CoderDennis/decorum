defmodule DecorumTest do
  use ExUnit.Case
  doctest Decorum

  alias Decorum.PRNG

  describe "check_all" do
    test "takes exactly 100 items from the generator" do
      # create a simple generator that just outputs the values it gets from the prng.
      decorum = Decorum.new(fn prng -> PRNG.next(prng) end)

      # create a hardcoded prng with the values 1 to 150
      prng = PRNG.hardcoded(Enum.to_list(1..150))

      # ensure that the value 100 is used
      assert_raise ExUnit.AssertionError,
                   ~r/Assertion with < failed, both sides are exactly equal/,
                   fn ->
                     Decorum.check_all(decorum, prng, fn x -> assert x < 100 end)
                   end

      # check that the value 101 is not used
      Decorum.check_all(decorum, prng, fn x -> assert x < 101 end)
    end
  end
end
