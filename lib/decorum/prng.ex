defmodule Decorum.Prng do
  @moduledoc """
  `Prng` (pseudo random number generator) is a wrapper around the `:rand` module.

  It has 2 states:
  1. Random
    Uses `:rand` to generate random numbers and stores each one in history.

  2. Hardcoded
    Used to replay a previously recorded (or simplified) history.

  """

  @type t :: prng
  @type prng :: __MODULE__.Random.t() | __MODULE__.Hardcoded.t()

  defmodule EmptyHistoryError do
    @moduledoc false
    defexception [:message]
  end

  defmodule Random do
    @moduledoc false
    @type t :: %__MODULE__{state: :rand.state(), history: Decorum.History.t()}

    @enforce_keys [:state, :history]
    defstruct [:state, :history]

    @int32 Integer.pow(2, 32)

    @spec new() :: t
    def new do
      state = :rand.jump()
      %__MODULE__{state: state, history: []}
    end

    @spec next!(prng :: t()) :: {non_neg_integer(), t}
    def next!(%__MODULE__{state: state, history: history} = prng) do
      {value, new_state} = :rand.uniform_s(@int32, state)
      {value, %__MODULE__{prng | state: new_state, history: [value | history]}}
    end

    @spec get_history(prng :: t()) :: Decorum.History.t()
    def get_history(%__MODULE__{history: history}), do: Enum.reverse(history)
  end

  defmodule Hardcoded do
    @moduledoc false
    @type t :: %__MODULE__{
            wholeHistory: Decorum.History.t(),
            unusedHistory: Decorum.History.t()
          }

    @enforce_keys [:wholeHistory, :unusedHistory]
    defstruct [:wholeHistory, :unusedHistory]

    @spec new(history :: Decorum.History.t()) :: t
    def new(history) when is_list(history) do
      %__MODULE__{wholeHistory: history, unusedHistory: history}
    end

    @spec next!(prng :: t()) :: {non_neg_integer(), t()}
    def next!(%__MODULE__{unusedHistory: []} = _prng) do
      raise EmptyHistoryError, "PRNG history is empty"
    end

    def next!(%__MODULE__{unusedHistory: [value | rest]} = prng) do
      {value, %__MODULE__{prng | unusedHistory: rest}}
    end

    @spec get_history(prng :: t()) :: Decorum.History.t()
    def get_history(%__MODULE__{wholeHistory: history}), do: history
  end

  @spec random() :: t()
  defdelegate random(), to: __MODULE__.Random, as: :new

  @spec hardcoded(history :: Decorum.History.t()) :: t()
  defdelegate hardcoded(history), to: __MODULE__.Hardcoded, as: :new

  @spec next!(prng :: t()) :: {non_neg_integer(), t()}
  def next!(%__MODULE__.Random{} = prng), do: __MODULE__.Random.next!(prng)
  def next!(%__MODULE__.Hardcoded{} = prng), do: __MODULE__.Hardcoded.next!(prng)

  @spec get_history(prng :: t()) :: Decorum.History.t()
  def get_history(%__MODULE__.Random{} = prng), do: __MODULE__.Random.get_history(prng)
  def get_history(%__MODULE__.Hardcoded{} = prng), do: __MODULE__.Hardcoded.get_history(prng)
end
