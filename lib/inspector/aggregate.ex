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

  @default_max_concurrency System.schedulers_online() * 2
  @default_timeout 15_000

  @typedoc "A function grouped with its occurrence count."
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
      iex> results = Inspector.Aggregate.current_functions(pids)
      iex> is_list(results)
      true

  """
  @spec list_pids() :: [pid()]
  def list_pids, do: Process.list()

  @doc """
  Groups processes by their currently executing function and counts occurrences.

  Returns a list of `%{function: {M, F, A}, count: n}` maps sorted
  descending by count.

  ## Options

    * `:max_concurrency` — max parallel tasks (default: `schedulers_online * 2`)
    * `:timeout` — per-task timeout in ms (default: #{@default_timeout})

  """
  @spec current_functions([Utils.pid_input()], keyword()) :: [function_count()]
  def current_functions(pid_inputs, opts \\ []) do
    aggregate_by(pid_inputs, :current_function, opts)
  end

  @doc """
  Groups processes by the function that started them and counts occurrences.

  Returns a list of `%{function: {M, F, A}, count: n}` maps sorted
  descending by count.

  ## Options

    * `:max_concurrency` — max parallel tasks (default: `schedulers_online * 2`)
    * `:timeout` — per-task timeout in ms (default: #{@default_timeout})

  """
  @spec initial_calls([Utils.pid_input()], keyword()) :: [function_count()]
  def initial_calls(pid_inputs, opts \\ []) do
    aggregate_by(pid_inputs, :initial_call, opts)
  end

  defp aggregate_by(pid_inputs, info_key, opts) do
    max_concurrency = Keyword.get(opts, :max_concurrency, @default_max_concurrency)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    pid_inputs
    |> convert_pids()
    |> Task.async_stream(
      fn pid -> :erlang.process_info(pid, info_key) end,
      max_concurrency: max_concurrency,
      timeout: timeout,
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
