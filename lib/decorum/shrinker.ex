defmodule Decorum.Shrinker do
  @moduledoc false

  alias Decorum.History
  alias Decorum.History.Chunk
  alias Decorum.PRNG

  @type value :: term()

  @type check_result :: :ok | {:error, String.t()}

  @type check_function(value) :: (value -> check_result())

  @type check_history_result(value) :: :fail | {:pass, History.t(), value, String.t()}

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
  def shrink(check_function, generator, value, history, message) do
    case shrink_by_chunks(check_function, generator, history) do
      {:pass, history, value, message} ->
        shrink(check_function, generator, value, history, message)

      :fail ->
        {new_value, new_history, new_message} =
          binary_search(check_function, generator, value, message, history)

        if new_history != history do
          shrink(check_function, generator, new_value, new_history, new_message)
        else
          raise Decorum.PropertyError,
            message: Enum.join([inspect(value), message], "\n\n"),
            value: value
        end
    end
  end

  @spec shrink_by_chunks(check_function(value), Decorum.generator_fun(value), History.t()) ::
          check_history_result(value)
  defp shrink_by_chunks(check_function, generator, history) do
    history_length = Enum.count(history)

    chunks =
      min(history_length, 4)..1
      |> Enum.flat_map(fn chunk_length ->
        Chunk.chunks(history_length, chunk_length)
      end)

    Stream.concat([
      Stream.map(chunks, &History.delete_chunk(history, &1)),
      Stream.map(chunks, &History.replace_chunk_with_zero(history, &1))
      # Stream.map(chunks, &History.sort_chunk(history, &1))
    ])
    |> Enum.filter(&(&1 != history))
    |> Enum.map(&check_history(&1, generator, check_function))
    |> Enum.find(:fail, &(&1 != :fail))
  end

  defp binary_search(check_function, generator, value, message, [first_value | post_history]) do
    binary_search(check_function, generator, value, message, [], post_history, 0, first_value)
  end

  defp binary_search(_check_function, _generator, value, message, pre_history, [], low, high)
       when low >= high - 1 do
    {value, Enum.reverse([high | pre_history]), message}
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
      [high | pre_history],
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
    history = Enum.reverse([mid | pre_history]) ++ post_history

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

      {:pass, _, value, message} ->
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
          check_history_result(value)
  defp check_history([], _, _), do: :fail

  defp check_history(history, generator, check_function) do
    prng = PRNG.hardcoded(history)

    try do
      {value, prng} = generator.(prng)

      case check_function.(value) do
        :ok -> :fail
        {:error, message} -> {:pass, PRNG.get_history(prng), value, message}
      end
    rescue
      Decorum.EmptyHistoryError -> :fail
    end
  end
end
