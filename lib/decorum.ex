defmodule Decorum do
  @moduledoc """
  Documentation for `Decorum`.
  """

  @doc """
  `for_all` takes a single `generator`, which needs to be enumerable
  and runs `body_fn` against it.

  This funciton will expand and eventually be called by a macro, but for now it's part
  of bootsrtapping the property testing functionality.
  """
  def for_all(generator, body_fn) do
    generator
    |> Enum.take(100)
    |> Enum.each(fn value ->
      unless body_fn.(value) do
        # raise an error so that ExUnit can report the test failure.
        raise "Test failed with value: #{value}"
      end
    end)
  end
end
