defmodule Inspector.Aggregate do
  @moduledoc """
  Aggregate statistics across a list of processes.

  Groups processes by their current or initial function and returns
  counts sorted descending. Uses `Task.async_stream` for parallel
  info fetching.

  All functions accept PIDs in any format supported by `Inspector.Utils`.
  Dead or invalid PIDs are silently skipped.
  """

  alias Inspector.Utils

  @type function_count :: %{
          function: {module(), atom(), arity()},
          count: pos_integer()
        }

  @doc """
  Returns a list of all PIDs in the local node.

  Convenience wrapper around `Process.list/0` for piping into
  `current_functions/1` or `initial_calls/1`.

  ## Examples

      iex> pids = Inspector.Aggregate.list_pids()
      iex> {:ok, _results} = Inspector.Aggregate.current_functions(pids)

  """
  @spec list_pids() :: [pid()]
  def list_pids, do: Process.list()

  @doc """
  Groups processes by their currently executing function and counts occurrences.

  Returns a list of `%{function: {M, F, A}, count: n}` maps sorted
  descending by count.

  ## Examples

      iex> pids = Process.list()
      iex> {:ok, results} = Inspector.Aggregate.current_functions(pids)
      iex> [%{function: {_, _, _}, count: _} | _] = results

  """
  @spec current_functions([Utils.pid_input()]) :: {:ok, [function_count()]}
  def current_functions(pid_inputs) do
    {:ok, aggregate_by(pid_inputs, :current_function)}
  end

  @doc """
  Groups processes by the function that started them and counts occurrences.

  Returns a list of `%{function: {M, F, A}, count: n}` maps sorted
  descending by count.

  ## Examples

      iex> pids = Process.list()
      iex> {:ok, results} = Inspector.Aggregate.initial_calls(pids)
      iex> [%{function: {_, _, _}, count: _} | _] = results

  """
  @spec initial_calls([Utils.pid_input()]) :: {:ok, [function_count()]}
  def initial_calls(pid_inputs) do
    {:ok, aggregate_by(pid_inputs, :initial_call)}
  end

  defp aggregate_by(pid_inputs, info_key) do
    pid_inputs
    |> convert_pids()
    |> Task.async_stream(
      fn pid -> :erlang.process_info(pid, info_key) end,
      ordered: false
    )
    |> Stream.flat_map(fn
      {:ok, {_key, mfa}} when is_tuple(mfa) -> [mfa]
      _ -> []
    end)
    |> Enum.frequencies()
    |> Enum.map(fn {function, count} -> %{function: function, count: count} end)
    |> Enum.sort_by(& &1.count, :desc)
  end

  defp convert_pids(pid_inputs) do
    Enum.flat_map(pid_inputs, fn input ->
      case Utils.safe_to_pid(input) do
        {:ok, pid} -> [pid]
        {:error, _} -> []
      end
    end)
  end
end
