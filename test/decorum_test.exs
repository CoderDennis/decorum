defmodule DecorumTest do
  use ExUnit.Case
  doctest Decorum

  test "greets the world" do
    assert Decorum.hello() == :world
  end
end
