defmodule Decorum.PRNG do
  @moduledoc """
  `PRNG` (pseudo random number generator) is a wrapper around the `:rand` module.

  It has 2 states:
  1. Random
    Uses `:rand` to generate random numbers and stores each one in history.

  2. Hardcoded
    Used to replay a previously recorded (or simplified) history.

  """

  @type t :: prng
  @type prng :: __MODULE__.Random.t() | __MODULE__.Hardcoded.t()
  @type history :: list(non_neg_integer())

  defmodule Random do
    @moduledoc false
    @type t :: %__MODULE__{state: :rand.state(), history: Decorum.PRNG.history()}

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

    @spec get_history(prng :: t()) :: Decorum.PRNG.history()
    def get_history(%__MODULE__{history: history}), do: Enum.reverse(history)
  end

  defmodule Hardcoded do
    @moduledoc false
    @type t :: %__MODULE__{wholeHistory: Decorum.PRNG.history(),
    unusedHistory: Decorum.PRNG.history()}

    @enforce_keys [:wholeHistory, :unusedHistory]
    defstruct [:wholeHistory, :unusedHistory]

    @spec new(history :: Decorum.PRNG.history()) :: t
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

    @spec get_history(prng :: t()) :: Decorum.PRNG.history()
    def get_history(%__MODULE__{wholeHistory: history}), do: history
  end

  @spec random(seed :: non_neg_integer()) :: t()
  defdelegate random(seed), to: __MODULE__.Random, as: :new

  @spec hardcoded(history :: history()) :: t()
  defdelegate hardcoded(history), to: __MODULE__.Hardcoded, as: :new

  @spec next(prng :: t()) :: {non_neg_integer() | :error, t()}
  def next(%__MODULE__.Random{} = prng), do: __MODULE__.Random.next(prng)
  def next(%__MODULE__.Hardcoded{} = prng), do: __MODULE__.Hardcoded.next(prng)

  @spec get_history(prng :: t()) :: history()
  def get_history(%__MODULE__.Random{} = prng), do: __MODULE__.Random.get_history(prng)
  def get_history(%__MODULE__.Hardcoded{} = prng), do: __MODULE__.Hardcoded.get_history(prng)
end
