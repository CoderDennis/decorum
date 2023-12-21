defmodule Decorum do
  @moduledoc """
  Documentation for `Decorum`.
  """

  alias Decorum.History
  alias Decorum.Prng

  @type generator_fun(a) :: (Prng.t() -> {a, Prng.t()})

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
  Used to run a Decorum generator with a specific Prng struct.

  Takes a Decorum struct and a Prng struct and returns a lazy Enumerable
  of generated values.
  """
  @spec stream(t(a), Prng.t()) :: Enumerable.t(a) when a: term()
  def stream(%__MODULE__{generator: generator}, prng) do
    Stream.unfold(prng, generator)
  end

  @doc """
  `check_all` takes a Decorum struct and runs `test_fn`
  against the generated values.

  This funciton will expand and eventually be called by a macro, but for now it's part
  of bootsrtapping the property testing functionality.

  `test_fn` should behaive like a normal ExUnit test. It throws an error if a test fails.
  Use the assert or other test helper macros inside that function.

  TODO: Create a Decorum.Error and raise that instead of ExUnit.AssertionError.
  """
  @spec check_all(t(a), (a -> nil)) :: :ok when a: term()
  def check_all(%__MODULE__{generator: generator}, test_fn) do
    1..100
    |> Enum.each(fn _ ->
      {value, prng} = generator.(Prng.random())

      try do
        test_fn.(value)
      rescue
        exception ->
          try do
            shrink(Prng.get_history(prng), generator, test_fn, MapSet.new())
          rescue
            shrunk_exception ->
              reraise shrunk_exception, __STACKTRACE__
          else
            _ -> reraise exception, __STACKTRACE__
          end
      end
    end)
  end

  defp shrink([], _generator, _test_fn, _seen), do: :ok

  defp shrink(history, generator, test_fn, seen) do
    {seen, new_history, exception, stacktrace} =
      history
      |> History.shrink()
      |> Enum.take(200)
      |> Enum.reduce_while({seen, history, nil, nil}, fn hist, {seen, _, _, _} ->
        if MapSet.member?(seen, hist) do
          {:cont, {seen, history, nil, nil}}
        else
          seen = MapSet.put(seen, hist)

          try do
            {value, _} = generator.(Prng.hardcoded(hist))
            test_fn.(value)
            {:cont, {seen, hist, nil, nil}}
          rescue
            Decorum.Prng.EmptyHistoryError ->
              {:cont, {seen, history, nil, nil}}

            exception ->
              {:halt, {seen, hist, exception, __STACKTRACE__}}
          end
        end
      end)

    if new_history != history do
      try do
        shrink(new_history, generator, test_fn, seen)
      rescue
        shrunk_exception ->
          reraise shrunk_exception, __STACKTRACE__
      else
        _ ->
          if exception != nil do
            reraise exception, stacktrace
          else
            :ok
          end
      end
    else
      :ok
    end
  end

  ## Generators

  @doc """
  Creates a simple generator that outputs the values it gets from the prng.

  Values will be 32-bit positive integers.
  """
  @spec prng_values() :: t(non_neg_integer)
  def prng_values do
    new(fn prng -> Prng.next!(prng) end)
  end

  @doc """
  Create a generator that is not random and always returns the same value.
  """
  @spec constant(a) :: t(a) when a: term()
  def constant(value) do
    new(fn prng -> {value, prng} end)
  end

  @doc """
  Generates integers in the given range.

  Range handling borrowed from StreamData

  Shrinks toward zero within the range.
  """
  @spec integer(Range.t()) :: t(integer())
  def integer(%Range{first: low, last: high, step: step} = _range) when high < low do
    integer(high..low//step)
  end

  def integer(%Range{first: value, last: value} = _range) do
    constant(value)
  end

  def integer(%Range{first: low, last: high, step: 1} = _range) when low >= 0 do
    # high and low are both non-negative.
    uniform_integer(high - low)
    |> map(fn n -> n + low end)
  end

  def integer(%Range{first: low, last: high, step: 1} = _range) when high <= 0 do
    # high and low are both negative and we still want to shrink toward zero.
    uniform_integer(high - low)
    |> map(fn n -> n * -1 + high end)
  end

  def integer(%Range{first: low, last: high, step: 1} = _range) do
    # high >= 1 and low <= -1 and we still want to shrink toward zero.
    one_of([
      integer(0..high),
      integer(low..-1)
    ])
  end

  def integer(%Range{first: low, last: high, step: step} = _range) do
    low_stepless = Integer.floor_div(low, step)
    high_stepless = Integer.floor_div(high, step)

    integer(low_stepless..high_stepless)
    |> map(fn value -> value * step end)
  end

  @doc """
  Randomly selects one of the given generators.

  `generators` must be a list.
  """
  @spec one_of([t(a)]) :: t(a) when a: term()
  def one_of([]) do
    raise "one_of needs at least one item"
  end

  def one_of([generator]) do
    generator
  end

  def one_of(generators) do
    generators = List.to_tuple(generators)

    (tuple_size(generators) - 1)
    |> uniform_integer()
    |> and_then(fn index -> elem(generators, index) end)
  end

  @doc """
  Generates a list of values produced by the given generator

  Use a biased coin flip to determine if another value should be gerenated or the list should be terminated
  """
  @spec list_of(t(a)) :: t([a]) when a: term()
  def list_of(%Decorum{generator: generator}) do
    new(fn prng ->
      Stream.cycle(1..1)
      |> Enum.reduce_while({[], prng}, fn _, {list, prng} ->
        {flip, prng} = Prng.next!(prng)

        if rem(flip, 10) > 0 do
          {value, prng} = generator.(prng)
          {:cont, {[value | list], prng}}
        else
          {:halt, {Enum.reverse(list), prng}}
        end
      end)
    end)
  end

  @doc """
  Generates an integer between 0 and max.

  Currently only supports 32-bit values and is not truly uniform as the use of `rem`
  has a bias towards producing smaller numbers.
  """
  @spec uniform_integer(non_neg_integer()) :: t(non_neg_integer())
  def uniform_integer(max) do
    new(fn prng ->
      {value, prng} = Prng.next!(prng)
      {rem(value, max + 1), prng}
    end)
  end

  def uniform_integer do
    uniform_integer(Integer.pow(2, 32) - 1)
  end

  ## Helpers

  @doc """

  In StreamData this funciton is called `bind`.
  """
  @spec and_then(t(a), (a -> t(b))) :: t(b) when a: term(), b: term()
  def and_then(%Decorum{generator: generator}, fun) when is_function(fun, 1) do
    new(fn prng ->
      {value, prng} = generator.(prng)
      %Decorum{generator: generator_b} = fun.(value)
      generator_b.(prng)
    end)
  end

  @spec map(t(a), (a -> b)) :: t(b) when a: term(), b: term()
  def map(%Decorum{generator: generator}, fun) when is_function(fun, 1) do
    new(fn prng ->
      {value, prng} = generator.(prng)
      {fun.(value), prng}
    end)
  end

  @spec zip(t(a), t(b)) :: t({a, b}) when a: term(), b: term()
  def zip(%Decorum{generator: generator_a}, %Decorum{generator: generator_b}) do
    new(fn prng ->
      {value_a, prng} = generator_a.(prng)
      {value_b, prng} = generator_b.(prng)
      {{value_a, value_b}, prng}
    end)
  end

  @spec zip([t(any())]) :: t(tuple())
  def zip(generators) do
    new(fn prng ->
      {value_list, prng} =
        generators
        |> Enum.reduce({[], prng}, fn %Decorum{generator: generator}, {values, prng} ->
          {value, prng} = generator.(prng)
          {[value | values], prng}
        end)

      {
        value_list
        |> Enum.reverse()
        |> List.to_tuple(),
        prng
      }
    end)
  end

  ## Enumerable

  defimpl Enumerable do
    def reduce(decorum, acc, fun) do
      reduce(decorum, acc, fun, Prng.random())
    end

    defp reduce(_decorum, {:halt, acc}, _fun, _prng) do
      {:halted, acc}
    end

    defp reduce(decorum, {:suspend, acc}, fun, prng) do
      {:suspended, acc, &reduce(decorum, &1, fun, prng)}
    end

    defp reduce(%Decorum{generator: generator} = decorum, {:cont, acc}, fun, prng) do
      {value, prng} = generator.(prng)
      reduce(decorum, fun.(value, acc), fun, prng)
    end

    def count(_decorum), do: {:error, __MODULE__}

    def member?(_decorum, _term), do: {:error, __MODULE__}

    def slice(_decorum), do: {:error, __MODULE__}
  end
end
