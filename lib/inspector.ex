defmodule Inspector do
  @moduledoc """
  Convenience functions for inspecting processes in a running BEAM system.

  Wraps `:recon` and `:erlang.process_info` to provide structured, safe
  access to process internals. All PID arguments accept multiple formats —
  see `Inspector.Utils` for details.

  ## Modules

    * `Inspector.Utils` — PID/port parsing/conversion
    * `Inspector.Process` — single-process inspection
    * `Inspector.Top` — top N processes by attribute
    * `Inspector.Aggregate` — function-count aggregations
    * `Inspector.Network` — top N network ports by packet/byte metrics
    * `Inspector.Port` — detailed port inspection
    * `Inspector.System` — port types, node stats, scheduler usage
  """

  # -- Process inspection (delegates to Inspector.Process) --

  @doc """
  Returns detailed info about a process as a categorized map.

  See `Inspector.Process.info/1` for return shape and details.
  """
  defdelegate process_info(pid_input), to: Inspector.Process, as: :info

  @doc """
  Returns messages from a process's mailbox with safety limits.

  See `Inspector.Process.mailbox/2` for options and safety notes.
  """
  defdelegate mailbox(pid_input, opts \\ []), to: Inspector.Process

  @doc """
  Returns the internal state of an OTP process.

  See `Inspector.Process.state/2` for options.
  """
  defdelegate state(pid_input, opts \\ []), to: Inspector.Process

  # -- Top N (delegates to Inspector.Top) --

  @doc """
  Returns the top `n` processes by the given attribute.

  See `Inspector.Top.top/3` for options, return shape, and supported attributes.
  """
  @spec top(atom(), pos_integer(), keyword()) ::
          {:ok, [Inspector.Top.result()]} | {:error, term()}
  def top(attribute), do: Inspector.Top.top(attribute)
  def top(attribute, n) when is_integer(n), do: Inspector.Top.top(attribute, n, [])
  def top(attribute, opts) when is_list(opts), do: Inspector.Top.top(attribute, opts)
  def top(attribute, n, opts), do: Inspector.Top.top(attribute, n, opts)

  @doc """
  Top `n` processes by memory usage (bytes).

  See `Inspector.Top.top/3` for options and return shape.
  """
  @spec top_memory(pos_integer(), keyword()) ::
          {:ok, [Inspector.Top.result()]} | {:error, term()}
  def top_memory, do: Inspector.Top.top_memory()
  def top_memory(n) when is_integer(n), do: Inspector.Top.top_memory(n)
  def top_memory(opts) when is_list(opts), do: Inspector.Top.top_memory(opts)
  def top_memory(n, opts), do: Inspector.Top.top_memory(n, opts)

  @doc """
  Top `n` processes by reduction count.

  See `Inspector.Top.top/3` for options and return shape.
  """
  @spec top_reductions(pos_integer(), keyword()) ::
          {:ok, [Inspector.Top.result()]} | {:error, term()}
  def top_reductions, do: Inspector.Top.top_reductions()
  def top_reductions(n) when is_integer(n), do: Inspector.Top.top_reductions(n)
  def top_reductions(opts) when is_list(opts), do: Inspector.Top.top_reductions(opts)
  def top_reductions(n, opts), do: Inspector.Top.top_reductions(n, opts)

  @doc """
  Top `n` processes by message queue length.

  See `Inspector.Top.top/3` for options and return shape.
  """
  @spec top_message_queue(pos_integer(), keyword()) ::
          {:ok, [Inspector.Top.result()]} | {:error, term()}
  def top_message_queue, do: Inspector.Top.top_message_queue()
  def top_message_queue(n) when is_integer(n), do: Inspector.Top.top_message_queue(n)
  def top_message_queue(opts) when is_list(opts), do: Inspector.Top.top_message_queue(opts)
  def top_message_queue(n, opts), do: Inspector.Top.top_message_queue(n, opts)

  @doc """
  Top `n` processes by total heap size (words).

  See `Inspector.Top.top/3` for options and return shape.
  """
  @spec top_total_heap(pos_integer(), keyword()) ::
          {:ok, [Inspector.Top.result()]} | {:error, term()}
  def top_total_heap, do: Inspector.Top.top_total_heap()
  def top_total_heap(n) when is_integer(n), do: Inspector.Top.top_total_heap(n)
  def top_total_heap(opts) when is_list(opts), do: Inspector.Top.top_total_heap(opts)
  def top_total_heap(n, opts), do: Inspector.Top.top_total_heap(n, opts)

  @doc """
  Top `n` processes by heap size (words).

  See `Inspector.Top.top/3` for options and return shape.
  """
  @spec top_heap(pos_integer(), keyword()) ::
          {:ok, [Inspector.Top.result()]} | {:error, term()}
  def top_heap, do: Inspector.Top.top_heap()
  def top_heap(n) when is_integer(n), do: Inspector.Top.top_heap(n)
  def top_heap(opts) when is_list(opts), do: Inspector.Top.top_heap(opts)
  def top_heap(n, opts), do: Inspector.Top.top_heap(n, opts)

  @doc """
  Top `n` processes by stack size (words).

  See `Inspector.Top.top/3` for options and return shape.
  """
  @spec top_stack(pos_integer(), keyword()) ::
          {:ok, [Inspector.Top.result()]} | {:error, term()}
  def top_stack, do: Inspector.Top.top_stack()
  def top_stack(n) when is_integer(n), do: Inspector.Top.top_stack(n)
  def top_stack(opts) when is_list(opts), do: Inspector.Top.top_stack(opts)
  def top_stack(n, opts), do: Inspector.Top.top_stack(n, opts)

  # -- Aggregates (delegates to Inspector.Aggregate) --

  @doc """
  Returns a list of all PIDs in the local node.

  See `Inspector.Aggregate.list_pids/0`.
  """
  defdelegate list_pids(), to: Inspector.Aggregate

  @doc """
  Groups processes by their currently executing function, returns counts descending.

  See `Inspector.Aggregate.current_functions/2` for options.
  """
  defdelegate current_functions(pid_inputs, opts \\ []), to: Inspector.Aggregate

  @doc """
  Groups processes by the function that started them, returns counts descending.

  See `Inspector.Aggregate.initial_calls/2` for options.
  """
  defdelegate initial_calls(pid_inputs, opts \\ []), to: Inspector.Aggregate

  # -- Network (delegates to Inspector.Network) --

  @doc """
  Top `n` network ports by attribute (absolute snapshot).

  See `Inspector.Network.inet_count/2`.
  """
  @spec inet_count(atom(), pos_integer()) ::
          {:ok, [Inspector.Network.result()]} | {:error, term()}
  defdelegate inet_count(attribute \\ :cnt, n \\ 10), to: Inspector.Network

  @doc """
  Top `n` network ports by attribute over a time window.

  See `Inspector.Network.inet_window/3`.
  """
  @spec inet_window(atom(), pos_integer(), pos_integer()) ::
          {:ok, [Inspector.Network.result()]} | {:error, term()}
  defdelegate inet_window(attribute \\ :cnt, n \\ 10, millis \\ 1000), to: Inspector.Network

  # -- Port (delegates to Inspector.Port) --

  @doc """
  Returns detailed info about a port.

  See `Inspector.Port.info/1`.
  """
  @spec port_info(Inspector.Utils.port_input()) :: {:ok, term()} | {:error, term()}
  defdelegate port_info(port_input), to: Inspector.Port, as: :info

  # -- System (delegates to Inspector.System) --

  @doc """
  Returns all port types currently open with their counts.

  See `Inspector.System.port_types/0`.
  """
  @spec port_types() :: {:ok, [{charlist(), pos_integer()}]}
  defdelegate port_types(), to: Inspector.System

  @doc """
  Samples node statistics.

  See `Inspector.System.node_stats/2`.
  """
  @spec node_stats(non_neg_integer(), non_neg_integer()) :: {:ok, term()} | {:error, term()}
  defdelegate node_stats(repeat \\ 1, interval \\ 0), to: Inspector.System

  @doc """
  Measures scheduler utilization over a time window.

  See `Inspector.System.scheduler_usage/1`.
  """
  @spec scheduler_usage(pos_integer()) :: {:ok, [{pos_integer(), float()}]} | {:error, term()}
  defdelegate scheduler_usage(millis \\ 1000), to: Inspector.System

  # -- Tracing (delegates to Inspector.Tracing) --

  @doc """
  Profiles function calls for the given pid(s) using `:eprof`.

  See `Inspector.Tracing.profile/2`.
  """
  @spec profile(
          pid() | Inspector.Utils.pid_input() | [Inspector.Utils.pid_input()],
          non_neg_integer()
        ) ::
          {:ok, :done} | {:error, term()}
  defdelegate profile(pid_input, duration_ms \\ 10), to: Inspector.Tracing
end
