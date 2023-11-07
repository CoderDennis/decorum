defmodule Decorum do
  @moduledoc """
  Documentation for `Decorum`.
  """

  alias Decorum.PRNG

  @type generator_fun(a) :: (PRNG.t() -> {a, PRNG.t()})

  @type t(a) :: %__MODULE__{generator: generator_fun(a)}

  defstruct [:generator]

  @doc """
  Helper for creating Decorum structs from a generator function.
  """
  @spec new(generator_fun(a)) :: t(a) when a: term()
  def new(generator) when is_function(generator, 1) do
    %__MODULE__{generator: generator}
  end

  @doc """
  Used to run a Decorum generator with a specific PRNG struct.

  Takes a Decorum struct and a PRNG struct and returns a lazy Enumerable
  of generated values.
  """
  @spec stream(t(a), PRNG.t()) :: Enumerable.t(a) when a: term()
  def stream(%__MODULE__{generator: generator}, prng) do
    Stream.unfold(prng, generator)
  end

  @doc """
  `check_all` takes a Decorum struct and a PRNG struct and runs `body_fn`
  against the generated values.

  This funciton will expand and eventually be called by a macro, but for now it's part
  of bootsrtapping the property testing functionality.

  `body_fn` should behaive like a normal ExUnit test. It throws an error if a test fails.
  Use the assert or other test helper macros inside that function.

  TODO: Create a Decorum.Error and raise that instead of ExUnit.AssertionError.
  """
  @spec check_all(t(a), PRNG.t(), (a -> nil)) :: :ok when a: term()
  def check_all(decorum, prng, body_fn) do
    decorum
    |> stream(prng)
    |> Enum.take(100)
    |> Enum.each(fn value ->
      body_fn.(value)
    end)
  end

  ## Generators

  @doc """
  Creates a simple Decorum struct with a generator that just outputs the values
  it gets from the prng.

  Values will be 32-bit positive integers.
  """
  def pos_integer() do
    Decorum.new(fn prng -> PRNG.next(prng) end)
  end

  ## Enumerable

  defimpl Enumerable do
    def reduce(data, acc, fun) do
      reduce(data, acc, fun, PRNG.random())
    end

    defp reduce(_data, {:halt, acc}, _fun, _prng) do
      {:halted, acc}
    end

    defp reduce(data, {:suspend, acc}, fun, prng) do
      {:suspended, acc, &reduce(data, &1, fun, prng)}
    end

    defp reduce(%Decorum{generator: generator} = data, {:cont, acc}, fun, prng) do
      {value, prng} = generator.(prng)
      reduce(data, fun.(value, acc), fun, prng)
    end

    def count(_data), do: {:error, __MODULE__}

    def member?(_data, _term), do: {:error, __MODULE__}

    def slice(_data), do: {:error, __MODULE__}
  end
end
