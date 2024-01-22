defmodule Decorum.Shrinker do
  @moduledoc """

  Binary Search (from Martin)
  We always try new values - the floored average of low and high. In each new loop we change either low or high to be the average, never both. So something like:

  0,100 -> middle 50; shrink attempt failed (either value didn't generate or it passed the test) so we go up (set low := mid), because we know that at all times, _high_ works and _low_ doesn't work and we want to keep it that way
  50,100 -> middle 75; shrink attempt passed so we go down (set high := mid)
  50,75 -> middle 62; shrink attempt succeeded so we go down
  ...
  etc. until we get to the moment where low and high are next to each other (eg. 53,54) and we return _high_ as the found minimum.
  """
  alias Decorum.History
  alias Decorum.History.Chunk
  alias Decorum.Prng

  @type value :: term()

  @type check_result :: :ok | {:error, String.t()}

  @type check_function(value) :: (value -> check_result())

  @doc """
  Takes a PRNG history and shrinks it to smaller values
  using a number of chunk manipulation strategies.

  Smaller is defined as shorter or lower sort order.
  """
  @spec shrink(
          check_function(value),
          Decorum.generator_fun(value),
          value,
          History.t(),
          String.t()
        ) :: :ok
  def shrink(_, _, value, [], message) do
    # TODO: figure out why this function gets called with an empty history.
    raise Decorum.PropertyError, Enum.join([inspect(value), message], "\n\n")
  end

  def shrink(check_function, generator, value, history, message) do
    history_length = Enum.count(history)

    valid_histories =
      1..min(history_length, 4)
      |> Enum.flat_map(fn chunk_length ->
        Chunk.chunks(history_length, chunk_length)
      end)
      |> Enum.flat_map(fn chunk ->
        [
          History.delete_chunk(history, chunk),
          History.replace_chunk_with_zero(history, chunk)
        ]
      end)
      |> Enum.reduce([], fn hist, valid_histories ->
        if History.compare(hist, history) == :lt do
          case check_history(hist, generator, check_function) do
            :fail -> valid_histories
            {:pass, value, message} -> [{hist, value, message} | valid_histories]
          end
        else
          valid_histories
        end
      end)
      |> Enum.sort_by(fn {hist, _, _} -> hist end, History)

    if Enum.any?(valid_histories) do
      {history, value, message} = List.first(valid_histories)
      shrink(check_function, generator, value, history, message)
    else
      {new_value, new_history, new_message} =
        binary_search(check_function, generator, value, message, history)

      if new_history != history do
        shrink(check_function, generator, new_value, new_history, new_message)
      end
    end

    raise Decorum.PropertyError, Enum.join([inspect(value), message], "\n\n")
  end

  defp binary_search(check_function, generator, value, message, [first_value | post_history]) do
    binary_search(check_function, generator, value, message, [], post_history, 0, first_value)
  end

  defp binary_search(_check_function, _generator, value, message, pre_history, [], low, high)
       when low >= high - 1 do
    {value, pre_history ++ [high], message}
  end

  defp binary_search(
         check_function,
         generator,
         value,
         message,
         pre_history,
         [next | post_history],
         low,
         high
       )
       when low >= high - 1 do
    binary_search(
      check_function,
      generator,
      value,
      message,
      pre_history ++ [high],
      post_history,
      0,
      next
    )
  end

  defp binary_search(
         check_function,
         generator,
         value,
         message,
         pre_history,
         post_history,
         low,
         high
       ) do
    mid = div(low + high, 2)
    history = pre_history ++ [mid] ++ post_history

    case check_history(history, generator, check_function) do
      :fail ->
        binary_search(
          check_function,
          generator,
          value,
          message,
          pre_history,
          post_history,
          mid,
          high
        )

      {:pass, value, message} ->
        binary_search(
          check_function,
          generator,
          value,
          message,
          pre_history,
          post_history,
          low,
          mid
        )
    end
  end

  @spec check_history(History.t(), Decorum.generator_fun(value), check_function(value)) ::
          :fail | {:pass, value, String.t()}
  defp check_history([], _, _), do: :fail

  defp check_history(history, generator, check_function) do
    prng = Prng.hardcoded(history)

    try do
      {value, _} = generator.(prng)

      case check_function.(value) do
        :ok -> :fail
        {:error, message} -> {:pass, value, message}
      end
    rescue
      Prng.EmptyHistoryError -> :fail
    end
  end
end
