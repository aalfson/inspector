defmodule Inspector.Dashboard.FunctionDefs do
  @moduledoc """
  Metadata definitions for Inspector functions exposed in the LiveDashboard page.
  """

  defp pid_input,
    do: %{name: :pid, label: "PID", type: :text, default: nil, placeholder: "0.123.0"}

  defp n_input, do: %{name: :n, label: "Count", type: :number, default: "10", placeholder: "10"}

  defp window_input do
    %{
      name: :window,
      label: "Window (ms)",
      type: :number,
      default: nil,
      placeholder: "optional, e.g. 1000"
    }
  end

  defp limit_input,
    do: %{name: :limit, label: "Limit", type: :number, default: "100", placeholder: "100"}

  defp timeout_input do
    %{
      name: :timeout,
      label: "Timeout (ms)",
      type: :number,
      default: "10000",
      placeholder: "10000"
    }
  end

  defp port_input,
    do: %{name: :port, label: "Port", type: :text, default: nil, placeholder: "#Port<0.6>"}

  defp inet_attribute_input do
    %{
      name: :attribute,
      label: "Attribute",
      type: :select,
      default: :cnt,
      options: ~w(cnt oct recv_cnt recv_oct send_cnt send_oct)a
    }
  end

  defp millis_input do
    %{
      name: :millis,
      label: "Window (ms)",
      type: :number,
      default: "1000",
      placeholder: "1000"
    }
  end

  defp repeat_input,
    do: %{name: :repeat, label: "Repeat", type: :number, default: "1", placeholder: "1"}

  defp interval_input,
    do: %{name: :interval, label: "Interval (ms)", type: :number, default: "0", placeholder: "0"}

  defp scheduler_millis_input do
    %{
      name: :millis,
      label: "Duration (ms)",
      type: :number,
      default: "1000",
      placeholder: "1000"
    }
  end

  defp defs do
    [
      %{
        key: :top_memory,
        label: "Top Memory",
        group: :top,
        description: "Top N processes by memory usage (bytes).",
        inputs: [n_input(), window_input()]
      },
      %{
        key: :top_reductions,
        label: "Top Reductions",
        group: :top,
        description: "Top N processes by reduction count.",
        inputs: [n_input(), window_input()]
      },
      %{
        key: :top_message_queue,
        label: "Top Message Queue",
        group: :top,
        description: "Top N processes by message queue length.",
        inputs: [n_input(), window_input()]
      },
      %{
        key: :top_total_heap,
        label: "Top Total Heap",
        group: :top,
        description: "Top N processes by total heap size (words).",
        inputs: [n_input(), window_input()]
      },
      %{
        key: :top_heap,
        label: "Top Heap",
        group: :top,
        description: "Top N processes by heap size (words).",
        inputs: [n_input(), window_input()]
      },
      %{
        key: :top_stack,
        label: "Top Stack",
        group: :top,
        description: "Top N processes by stack size (words).",
        inputs: [n_input(), window_input()]
      },
      %{
        key: :current_functions,
        label: "Current Functions",
        group: :aggregate,
        description: "Groups all processes by currently executing function, counts descending.",
        inputs: []
      },
      %{
        key: :initial_calls,
        label: "Initial Calls",
        group: :aggregate,
        description: "Groups all processes by initial call function, counts descending.",
        inputs: []
      },
      %{
        key: :process_info,
        label: "Process Info",
        group: :process,
        description: "Detailed info about a process: meta, signals, location, memory, work.",
        inputs: [pid_input()]
      },
      %{
        key: :mailbox,
        label: "Mailbox",
        group: :process,
        description: "Messages from a process's mailbox with safety limits.",
        inputs: [pid_input(), limit_input()]
      },
      %{
        key: :state,
        label: "State",
        group: :process,
        description: "Internal state of an OTP process (GenServer, gen_statem, etc).",
        inputs: [pid_input(), timeout_input()]
      },
      %{
        key: :inet_count,
        label: "Inet Count",
        group: :network,
        description: "Top N network ports by attribute (absolute snapshot).",
        inputs: [inet_attribute_input(), n_input()]
      },
      %{
        key: :inet_window,
        label: "Inet Window",
        group: :network,
        description: "Top N network ports by attribute over a time window.",
        inputs: [inet_attribute_input(), n_input(), millis_input()]
      },
      %{
        key: :port_info,
        label: "Port Info",
        group: :port,
        description: "Detailed info about a port.",
        inputs: [port_input()]
      },
      %{
        key: :port_types,
        label: "Port Types",
        group: :system,
        description: "All port types currently open with their counts.",
        inputs: []
      },
      %{
        key: :node_stats,
        label: "Node Stats",
        group: :system,
        description: "Sample node statistics (absolute values and deltas).",
        inputs: [repeat_input(), interval_input()]
      },
      %{
        key: :scheduler_usage,
        label: "Scheduler Usage",
        group: :system,
        description: "Scheduler utilization over a time window (0.0–1.0 per scheduler).",
        inputs: [scheduler_millis_input()]
      }
    ]
  end

  @spec all() :: [map()]
  def all, do: defs()

  @spec get(atom()) :: map() | nil
  def get(key) do
    Enum.find(defs(), &(&1.key == key))
  end

  @spec find_by_key_string(String.t()) :: map() | nil
  def find_by_key_string(key_str) do
    Enum.find(defs(), &(Atom.to_string(&1.key) == key_str))
  end

  @spec grouped() :: [{atom(), [map()]}]
  def grouped do
    defs()
    |> Enum.group_by(& &1.group)
    |> then(fn groups ->
      for group <- [:top, :aggregate, :process, :network, :port, :system],
          Map.has_key?(groups, group) do
        {group, Map.fetch!(groups, group)}
      end
    end)
  end

  # Execute dispatchers — called by Runner

  @spec execute(atom(), map()) :: term()
  def execute(:process_info, %{pid: pid}), do: Inspector.process_info(pid)

  def execute(:mailbox, %{pid: pid, limit: limit}) when is_integer(limit),
    do: Inspector.mailbox(pid, limit: limit)

  def execute(:mailbox, %{pid: pid}), do: Inspector.mailbox(pid)

  def execute(:state, %{pid: pid, timeout: timeout}) when is_integer(timeout),
    do: Inspector.state(pid, timeout: timeout)

  def execute(:state, %{pid: pid}), do: Inspector.state(pid)

  # Top functions — with optional window
  for func <- ~w(top_memory top_reductions top_message_queue top_total_heap top_heap top_stack)a do
    def execute(unquote(func), %{n: n, window: w}) when is_integer(n) and is_integer(w),
      do: apply(Inspector, unquote(func), [n, [window: w]])

    def execute(unquote(func), %{n: n}) when is_integer(n),
      do: apply(Inspector, unquote(func), [n])

    def execute(unquote(func), _),
      do: apply(Inspector, unquote(func), [])
  end

  def execute(:current_functions, _), do: Inspector.current_functions(Inspector.list_pids())
  def execute(:initial_calls, _), do: Inspector.initial_calls(Inspector.list_pids())

  # Network functions
  def execute(:inet_count, %{attribute: attr, n: n}) when is_atom(attr) and is_integer(n),
    do: Inspector.inet_count(attr, n)

  def execute(:inet_count, %{attribute: attr}) when is_atom(attr),
    do: Inspector.inet_count(attr)

  def execute(:inet_count, _), do: Inspector.inet_count()

  def execute(:inet_window, %{attribute: attr, n: n, millis: ms})
      when is_atom(attr) and is_integer(n) and is_integer(ms),
      do: Inspector.inet_window(attr, n, ms)

  def execute(:inet_window, %{attribute: attr, n: n}) when is_atom(attr) and is_integer(n),
    do: Inspector.inet_window(attr, n)

  def execute(:inet_window, %{attribute: attr}) when is_atom(attr),
    do: Inspector.inet_window(attr)

  def execute(:inet_window, _), do: Inspector.inet_window()

  # Port functions
  def execute(:port_info, %{port: port}), do: Inspector.port_info(port)

  # System functions
  def execute(:port_types, _), do: Inspector.port_types()

  def execute(:node_stats, %{repeat: r, interval: i}) when is_integer(r) and is_integer(i),
    do: Inspector.node_stats(r, i)

  def execute(:node_stats, %{repeat: r}) when is_integer(r),
    do: Inspector.node_stats(r)

  def execute(:node_stats, _), do: Inspector.node_stats()

  def execute(:scheduler_usage, %{millis: ms}) when is_integer(ms),
    do: Inspector.scheduler_usage(ms)

  def execute(:scheduler_usage, _), do: Inspector.scheduler_usage()

  def execute(key, _), do: {:error, "Unknown function: #{key}"}
end
