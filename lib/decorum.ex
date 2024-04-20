defmodule Decorum do
  @moduledoc """
  Documentation for `Decorum`.
  """

  alias Decorum.PRNG
  alias Decorum.Shrinker

  @type value :: term()

  @type generator_fun(value) :: (PRNG.t() -> {value, PRNG.t()})

  @type max_length :: non_neg_integer() | :none

  @type t(value) :: %__MODULE__{generator: generator_fun(value)}

  defstruct [:generator]

  @doc """
  Helper for creating Decorum structs from a generator function.
  """
  @spec new(generator_fun(value)) :: t(value)
  def new(generator) when is_function(generator, 1) do
    %__MODULE__{generator: generator}
  end

  @doc """
  Used to run a Decorum generator with a specific `PRNG` struct.

  Takes a Decorum struct and a `PRNG` struct and returns a lazy Enumerable
  of generated values.
  """
  @spec stream(t(value), PRNG.t()) :: Enumerable.t(value)
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
  @spec check_all(t(value), (value -> nil)) :: :ok
  def check_all(%__MODULE__{generator: generator}, test_fn) when is_function(test_fn, 1) do
    1..100
    |> Enum.each(fn _ ->
      {value, prng} = generator.(PRNG.random())

      case check(test_fn, value) do
        {:error, message} ->
          Shrinker.shrink(check(test_fn), generator, value, PRNG.get_history(prng), message)

        :ok ->
          :ok
      end
    end)
  end

  @spec check((value -> nil), value) :: Shrinker.check_result()
  def check(test_fn, test_value) when is_function(test_fn, 1) do
    try do
      test_fn.(test_value)
      :ok
    rescue
      exception ->
        {:error, exception.message}
    end
  end

  @spec check((value -> nil)) :: Shrinker.check_function(value)
  def check(test_fn) do
    fn test_value ->
      check(test_fn, test_value)
    end
  end

  ## Generators

  @doc """
  Creates a simple generator that outputs the values it gets from the prng.

  Values will be 32-bit positive integers.
  """
  @spec prng_values() :: t(non_neg_integer)
  def prng_values do
    new(fn prng -> PRNG.next!(prng) end)
  end

  @doc """
  Create a generator that is not random and always returns the same value.
  """
  @spec constant(value) :: t(value)
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
  @spec one_of([t(value)]) :: t(value)
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
  Generates a list of values produced by the given generator.

  `max_length` is used to cap the length of the list. It defaults to `:none`.

  Uses a biased coin flip to determine if another value should be gerenated
  or the list should be terminated.

  When `max_length` is a value other than `:none`,
  then the probablility of terminating the list increases as the list size approaches `max_length`.

  When `max_length` is `:none` the probablility of generating another value is around 7/8.
  """
  @spec list_of(t(value), max_length()) :: t([value])
  def list_of(%Decorum{generator: generator}, max_length \\ :none) do
    bias = fn flip, index ->
      case max_length do
        :none -> rem(flip, 8) > 0
        length -> rem(flip, length - index + 1) > 0
      end
    end

    new(fn prng ->
      Stream.iterate(0, &(&1 + 1))
      |> Enum.reduce_while({[], prng}, fn index, {list, prng} ->
        {flip, prng} = PRNG.next!(prng)

        if index < max_length and bias.(flip, index) do
          {value, prng} = generator.(prng)
          {:cont, {[value | list], prng}}
        else
          {:halt, {Enum.reverse(list), prng}}
        end
      end)
    end)
  end

  @spec list_of_length(t(value), non_neg_integer()) :: t(list(value))
  def list_of_length(decorum, length) do
    Stream.repeatedly(fn -> decorum end)
    |> Enum.take(length)
    |> zip()
    |> map(&Tuple.to_list/1)
  end

  @doc """
  Generates an integer between 0 and max.

  Currently only supports 32-bit values and is not truly uniform as the use of `rem`
  has a bias towards producing smaller numbers.
  """
  @spec uniform_integer(non_neg_integer()) :: t(non_neg_integer())
  def uniform_integer(max) do
    new(fn prng ->
      {value, prng} = PRNG.next!(prng)
      {rem(value, max + 1), prng}
    end)
  end

  @doc """
  Generates bytes.

  A byte is an integer between `0` and `255`.
  """
  @spec byte() :: t(byte())
  def byte() do
    uniform_integer(255)
  end

  @doc """
  Generates binaries.

  `max_length` is used to cap the length of the binary. It defaults to `:none` and is the same as in `list_of/2`.
  """
  @spec binary(max_length()) :: t(binary())
  def binary(max_length \\ :none) do
    map(list_of(byte(), max_length), &:binary.list_to_bin/1)
  end

  @doc """
  Generates alphanumeric atoms.

  *Warning!* Be careful when generating random atoms as the BEAM has a limit on how many atoms can be created
  and it will crash if that limit is exceeded.
  """
  @spec atom(max_length()) :: t(atom())
  def atom(max_length \\ :none) do
    atom_chars =
      [?a..?z, ?A..?Z, ?0..?9, [?_], [?@]]
      |> char_map()

    max_length =
      case max_length do
        :none -> :none
        length when length > 255 -> raise ArgumentError, "atoms cannot be over 255 characters"
        length -> length - 1
      end

    rest =
      (Enum.count(atom_chars) - 1)
      |> uniform_integer()
      |> list_of(max_length)
      |> filter(fn list -> Enum.count(list) < 255 end)
      |> map(fn indexes -> to_string(Enum.map(indexes, &atom_chars[&1])) end)

    starting_chars =
      [?a..?z, ?A..?Z, [?_]]
      |> char_map()

    starting_char =
      (Enum.count(starting_chars) - 1)
      |> uniform_integer()
      |> map(&starting_chars[&1])

    zip(starting_char, rest)
    |> map(fn {first, rest} -> String.to_atom(<<first, rest::binary>>) end)
  end

  defp char_map(characters) do
    characters
    |> Enum.flat_map(&Enum.to_list/1)
    |> Enum.with_index(fn ch, i -> {i, ch} end)
    |> Enum.into(%{})
  end

  ## Helpers

  @doc """
  Use this function to chain generators together when a generator is based on the
  value emitted by another generator.

  In StreamData this funciton is called `bind`.

  `fun` is a function that takes a value from the given generator and
  returns a generator.
  """
  @spec and_then(t(a), (a -> t(b))) :: t(b) when a: value, b: value
  def and_then(%Decorum{generator: generator}, fun) when is_function(fun, 1) do
    new(fn prng ->
      {value, prng} = generator.(prng)
      %Decorum{generator: generator_b} = fun.(value)
      generator_b.(prng)
    end)
  end

  @doc """
  Similar to Enum.map/2

  Returns a generator where each element is the result of invoking fun
  on each corresponding element of the given generator.
  """
  @spec map(t(a), (a -> b)) :: t(b) when a: value, b: value
  def map(%Decorum{generator: generator}, fun) when is_function(fun, 1) do
    new(fn prng ->
      {value, prng} = generator.(prng)
      {fun.(value), prng}
    end)
  end

  @doc """
  Similar to Enum.zip/2

  Zips corresponding elements from two generators into a generator of tuples.
  """
  @spec zip(t(a), t(b)) :: t({a, b}) when a: value, b: value
  def zip(%Decorum{generator: generator_a}, %Decorum{generator: generator_b}) do
    new(fn prng ->
      {value_a, prng} = generator_a.(prng)
      {value_b, prng} = generator_b.(prng)
      {{value_a, value_b}, prng}
    end)
  end

  @doc """
  Similar to Enum.zip/1

  Zips corresponding elements from a finite collection of generators into a
  generator of tuples.
  """
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

  defmodule FilterTooNarrowError do
    @moduledoc false
    defexception [:message]
  end

  defp loop_until(_prng, _generator, _fun, 0) do
    raise FilterTooNarrowError,
          "Decorum.filter did not find a matching value. Try widening the filter."
  end

  defp loop_until(prng, generator, fun, limit) do
    {value, prng} = generator.(prng)

    if fun.(value) do
      {value, prng}
    else
      loop_until(prng, generator, fun, limit - 1)
    end
  end

  @doc """
  Similar to Enum.filter/2

  Filters the generator. Returns only values for which fun returns a truthy value.

  Use `limit` to specify how many times the generator should be called before raising an error.

  """
  @spec filter(t(value), (value -> boolean)) :: t(value)
  def filter(%Decorum{generator: generator}, fun, limit \\ 25) do
    new(fn prng ->
      loop_until(prng, generator, fun, limit)
    end)
  end

  ## Enumerable

  defimpl Enumerable do
    def reduce(decorum, acc, fun) do
      reduce(decorum, acc, fun, PRNG.random())
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
