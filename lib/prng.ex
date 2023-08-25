defmodule PRNG do
  @moduledoc """
  `PRNG` (pseudo random number generator) is a wrapper around the `:rand` module.

  It has 2 states:
  1. Random
    Uses `:rand` to generate random numbers and stores each one in history.

  2. Hardcoded
    Used to replay a previously recorded (or simplified) history.

  """

  @type t :: prng
  @type prng :: PRNG.Random.t() | PRNG.Hardcoded.t()
  @type history :: list(non_neg_integer())

  defmodule Random do
    @moduledoc false
    @type t :: %__MODULE__{state: :rand.state(), history: PRNG.history()}

    @enforce_keys [:state, :history]
    defstruct [:state, :history]

    @int32 Integer.pow(2, 32)

    @spec new(seed :: non_neg_integer()) :: t
    def new(seed) do
      state = :rand.seed(:exsss, {seed, seed, seed})
      %__MODULE__{state: state, history: []}
    end

    @spec next(prng :: t()) :: {non_neg_integer(), t}
    def next(%__MODULE__{state: state, history: history} = prng) do
      {value, new_state} = :rand.uniform_s(@int32, state)
      {value, %__MODULE__{prng | state: new_state, history: [value | history]}}
    end

    @spec get_history(prng :: t()) :: PRNG.history()
    def get_history(%__MODULE__{history: history}), do: Enum.reverse(history)
  end

  defmodule Hardcoded do
    @moduledoc false
    @type t :: %__MODULE__{wholeHistory: PRNG.history(), unusedHistory: PRNG.history()}

    @enforce_keys [:wholeHistory, :unusedHistory]
    defstruct [:wholeHistory, :unusedHistory]

    @spec new(history :: PRNG.history()) :: t
    def new(history) when is_list(history) do
      %__MODULE__{wholeHistory: history, unusedHistory: history}
    end

    @spec next(prng :: t()) :: {non_neg_integer() | :error, t()}
    def next(%__MODULE__{unusedHistory: []} = prng) do
      {:error, prng}
    end

    def next(%__MODULE__{unusedHistory: [value | rest]} = prng) do
      {value, %__MODULE__{prng | unusedHistory: rest}}
    end

    @spec get_history(prng :: t()) :: PRNG.history()
    def get_history(%__MODULE__{wholeHistory: history}), do: history
  end

  @spec random(seed :: non_neg_integer()) :: t
  defdelegate random(seed), to: PRNG.Random, as: :new

  @spec hardcoded(history :: history()) :: t
  defdelegate hardcoded(history), to: PRNG.Hardcoded, as: :new

  @spec next(prng :: t()) :: {non_neg_integer() | :error, t()}
  def next(%PRNG.Random{} = prng), do: PRNG.Random.next(prng)
  def next(%PRNG.Hardcoded{} = prng), do: PRNG.Hardcoded.next(prng)

  @spec get_history(prng :: t()) :: history()
  def get_history(%PRNG.Random{} = prng), do: PRNG.Random.get_history(prng)
  def get_history(%PRNG.Hardcoded{} = prng), do: PRNG.Hardcoded.get_history(prng)
end
