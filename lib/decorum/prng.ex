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

  defmodule Random do
    @moduledoc """
    Wraps the `:rand` module and stores history of random numbers generated.
    """

    @type t :: %__MODULE__{state: :rand.state(), history: Decorum.History.t()}

    @enforce_keys [:state, :history]
    defstruct [:state, :history]

    @int32 Integer.pow(2, 32)

    @doc false
    @spec new() :: t
    def new do
      state = :rand.jump()
      %__MODULE__{state: state, history: []}
    end

    @doc false
    @spec next!(prng :: t()) :: {non_neg_integer(), t}
    def next!(%__MODULE__{state: state, history: history} = prng) do
      {value, new_state} = :rand.uniform_s(@int32, state)
      {value, %__MODULE__{prng | state: new_state, history: [value | history]}}
    end

    @doc false
    @spec get_history(prng :: t()) :: Decorum.History.t()
    def get_history(%__MODULE__{history: history}), do: Enum.reverse(history)
  end

  defmodule Hardcoded do
    @moduledoc """
    Replays a previously recorded (or simplified) PRNG history.
    """
    @type t :: %__MODULE__{
            history: Decorum.History.t(),
            unusedHistory: Decorum.History.t()
          }

    @enforce_keys [:history, :unusedHistory]
    defstruct [:history, :unusedHistory]

    @doc false
    @spec new(history :: Decorum.History.t()) :: t
    def new(history) when is_list(history) do
      %__MODULE__{history: [], unusedHistory: history}
    end

    @doc false
    @spec next!(prng :: t()) :: {non_neg_integer(), t()}
    def next!(%__MODULE__{unusedHistory: []} = _prng) do
      raise Decorum.EmptyHistoryError, "PRNG history is empty"
    end

    def next!(%__MODULE__{history: history, unusedHistory: [value | rest]} = prng) do
      {value, %__MODULE__{prng | history: [value | history], unusedHistory: rest}}
    end

    @doc false
    @spec get_history(prng :: t()) :: Decorum.History.t()
    def get_history(%__MODULE__{history: history}), do: Enum.reverse(history)
  end

  @spec random() :: t()
  def random(), do: __MODULE__.Random.new()

  @spec hardcoded(history :: Decorum.History.t()) :: t()
  def hardcoded(history), do: __MODULE__.Hardcoded.new(history)

  @spec next!(prng :: t()) :: {non_neg_integer(), t()}
  def next!(%__MODULE__.Random{} = prng), do: __MODULE__.Random.next!(prng)
  def next!(%__MODULE__.Hardcoded{} = prng), do: __MODULE__.Hardcoded.next!(prng)

  @spec get_history(prng :: t()) :: Decorum.History.t()
  def get_history(%__MODULE__.Random{} = prng), do: __MODULE__.Random.get_history(prng)
  def get_history(%__MODULE__.Hardcoded{} = prng), do: __MODULE__.Hardcoded.get_history(prng)
end
