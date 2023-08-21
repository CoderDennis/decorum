defmodule PRNG do
  @moduledoc """
  PRNG (pseudo random number generator) is a wrapper around the :rand module.

  It has 2 states:
  1. Random
    Uses :rand to generate random numbers and stores each one in history.

  2. Hardcoded
    Used to replay a previously recorded (or simplified) history.

  """

  @type t :: prng
  @type prng :: PRNG.Random.t() | PRNG.Hardcoded.t()
  @type history :: list(non_neg_integer())

  @int64 Integer.pow(2, 64)

  defmodule Random do
    @moduledoc false
    @type t :: %__MODULE__{state: :rand.state(), history: PRNG.history()}

    @enforce_keys [:state, :history]
    defstruct [:state, :history]

    @spec new(seed :: non_neg_integer()) :: t
    def new(seed) do
      state = :rand.seed(:exs1024s, {seed, seed, seed})
      %__MODULE__{state: state, history: []}
    end
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
  end

  @spec random(seed :: non_neg_integer()) :: t
  defdelegate random(seed), to: PRNG.Random, as: :new

  @spec hardcoded(history :: history) :: t
  defdelegate hardcoded(history), to: PRNG.Hardcoded, as: :new

  @spec next(t()) :: {non_neg_integer() | :error, t()}
  def next(%PRNG.Random{state: state, history: history} = prng) do
    {value, new_state} = :rand.uniform_s(@int64, state)
    {value, %PRNG.Random{prng | state: new_state, history: [value | history]}}
  end

  def next(%PRNG.Hardcoded{unusedHistory: []} = prng) do
    {:error, prng}
  end

  def next(%PRNG.Hardcoded{unusedHistory: [value | rest]} = prng) do
    {value, %PRNG.Hardcoded{prng | unusedHistory: rest}}
  end

  @spec get_history(t()) :: history()
  def get_history(%PRNG.Random{history: history}), do: Enum.reverse(history)
  def get_history(%PRNG.Hardcoded{wholeHistory: history}), do: history
end
