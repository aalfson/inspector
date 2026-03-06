defmodule Inspector.Tracing do
  @moduledoc """
  Production-safe tracing wrappers for BEAM profiling tools.

  Functions run inside a monitored task via `Inspector.TaskSupervisor`
  so a crash during profiling won't bring down the calling process.
  """

  @default_duration_ms 10

  @doc """
  Profiles function calls for the given pid(s) using `:eprof`.

  Starts eprof, profiles the target processes for `duration_ms`, then
  prints analysis to stdout via `:eprof.analyze/0`.

  ## Arguments

    * `pid_input` — a pid or list of pids (accepts any format supported by `Inspector.Utils.to_pid/1`)
    * `duration_ms` — sampling window in milliseconds (default: #{@default_duration_ms})

  ## Examples

      Inspector.Tracing.profile(pid)
      Inspector.Tracing.profile([pid1, pid2], 50)

  """
  @spec profile(
          pid() | Inspector.Utils.pid_input() | [Inspector.Utils.pid_input()],
          non_neg_integer()
        ) ::
          {:ok, :done} | {:error, term()}
  def profile(pid_input, duration_ms \\ @default_duration_ms) do
    with {:ok, pids} <- resolve_pids(pid_input) do
      task =
        Task.Supervisor.async_nolink(Inspector.TaskSupervisor, fn ->
          run_eprof(pids, duration_ms)
        end)

      case Task.yield(task, duration_ms + 5_000) || Task.shutdown(task) do
        {:ok, result} -> result
        {:exit, reason} -> {:error, {:task_crashed, reason}}
        nil -> {:error, :timeout}
      end
    end
  end

  defp run_eprof(pids, duration_ms) do
    IO.puts("[eprof] starting eprof server...")
    {:ok, _} = :eprof.start()

    try do
      IO.puts("[eprof] profiling #{length(pids)} process(es) for #{duration_ms}ms...")
      :eprof.start_profiling(pids)
      :timer.sleep(duration_ms)

      IO.puts("[eprof] stopping profiler...")
      :eprof.stop_profiling()

      IO.puts("[eprof] analyzing results (this may take some time):")
      :eprof.analyze()

      {:ok, :done}
    after
      IO.puts("[eprof] cleaning up...")
      :eprof.stop()
    end
  end

  defp resolve_pids(pid_input) when is_list(pid_input) do
    pid_input
    |> Enum.reduce_while([], fn input, acc ->
      case Inspector.Utils.safe_to_pid(input) do
        {:ok, pid} -> {:cont, [pid | acc]}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:error, _} = err -> err
      pids -> {:ok, Enum.reverse(pids)}
    end
  end

  defp resolve_pids(pid_input) do
    case Inspector.Utils.safe_to_pid(pid_input) do
      {:ok, pid} -> {:ok, [pid]}
      {:error, _} = err -> err
    end
  end
end
