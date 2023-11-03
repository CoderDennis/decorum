defmodule Decorum do
  @moduledoc """
  Documentation for `Decorum`.
  """

  @doc """
  `check_all` takes a single `generator`, which needs to be enumerable
  and runs `body_fn` against it.

  This funciton will expand and eventually be called by a macro, but for now it's part
  of bootsrtapping the property testing functionality.

  `body_fn` should behaive like a normal ExUnit test. It throws an error if a test fails.
  Use the assert or other macros inside that function.

  TODO: Create a Decorum.Error and raise that instead of ExUnit.AssertionError.
  """
  def check_all(generator, body_fn) do
    generator
    |> Enum.take(100)
    |> Enum.each(fn value ->
      body_fn.(value)
    end)
  end
end
