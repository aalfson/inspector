defmodule Inspector.System do
  @moduledoc """
  System-level BEAM inspection utilities.

  Wraps `:recon` functions for port types, node statistics, and scheduler usage.
  """

  @doc """
  Returns a list of all port types currently open with their counts.

  Wraps `:recon.port_types/0`.

  ## Examples

      iex> Inspector.System.port_types()
      {:ok, [{"efile", 23}, {"tcp_inet", 4}]}

  """
  @spec port_types() :: {:ok, [{String.t(), pos_integer()}]}
  def port_types do
    {:ok, :recon.port_types()}
  end

  @doc """
  Samples node statistics over `repeat` iterations with `interval` ms between samples.

  Wraps `:recon.node_stats_list/2`. Returns a list of stats tuples containing
  absolute values and incremental deltas.

  ## Defaults

    * `repeat` — `1`
    * `interval` — `0`

  ## Examples

      iex> Inspector.System.node_stats(3, 1000)
      {:ok, [{absolutes, deltas}, ...]}

  """
  @spec node_stats(non_neg_integer(), non_neg_integer()) :: {:ok, term()} | {:error, term()}
  def node_stats(repeat \\ 1, interval \\ 0)

  def node_stats(repeat, interval)
      when is_integer(repeat) and repeat >= 0 and is_integer(interval) and interval >= 0 do
    {:ok, :recon.node_stats_list(repeat, interval)}
  end

  def node_stats(repeat, _interval) when not is_integer(repeat) or repeat < 0 do
    {:error, :invalid_repeat}
  end

  def node_stats(_repeat, interval) when not is_integer(interval) or interval < 0 do
    {:error, :invalid_interval}
  end

  @doc """
  Measures scheduler utilization over `millis` milliseconds.

  Wraps `:recon.scheduler_usage/1`. Returns a list of `{scheduler_id, usage}`
  tuples where usage is a float between 0.0 and 1.0.

  ## Defaults

    * `millis` — `1000`

  ## Examples

      iex> Inspector.System.scheduler_usage(500)
      {:ok, [{1, 0.25}, {2, 0.10}, ...]}

  """
  @spec scheduler_usage(pos_integer()) :: {:ok, [{pos_integer(), float()}]} | {:error, term()}
  def scheduler_usage(millis \\ 1000)

  def scheduler_usage(millis) when is_integer(millis) and millis > 0 do
    {:ok, :recon.scheduler_usage(millis)}
  end

  def scheduler_usage(_millis), do: {:error, :invalid_millis}
end
