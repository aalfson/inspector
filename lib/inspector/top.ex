defmodule Inspector.Top do
  @moduledoc """
  Find the top N processes by various attributes.

  Wraps `:recon.proc_count/2` for absolute snapshots and `:recon.proc_window/3`
  for delta-based measurement over a time window. Results are returned as a list
  of maps sorted descending by value.

  ## Supported attributes

    * `:memory` — bytes of memory used
    * `:reductions` — reduction count
    * `:message_queue_len` — number of messages in the mailbox
    * `:total_heap_size` — total heap size in words
    * `:heap_size` — heap size in words
    * `:stack_size` — stack size in words
  """

  @type result :: %{
          pid: pid(),
          value: integer(),
          name: atom() | nil,
          initial_call: {module(), atom(), arity()},
          current_function: {module(), atom(), arity()}
        }

  @doc """
  Returns the top `n` processes by the given attribute.

  Uses `:recon.proc_count/2` for an absolute snapshot. When the `:window` option
  is provided (milliseconds), uses `:recon.proc_window/3` to measure the delta
  over that period instead.

  ## Options

    * `:window` — time window in milliseconds for delta-based measurement

  ## Return shape

      [
        %{
          pid: #PID<0.123.0>,
          value: 45678,
          name: :my_server,             # registered name or nil
          initial_call: {M, F, A},
          current_function: {M, F, A}
        },
        ...
      ]

  """
  @spec top(atom(), pos_integer(), keyword()) :: [result()]
  def top(attribute, n \\ 10, opts \\ []) do
    results =
      case Keyword.get(opts, :window) do
        nil -> :recon.proc_count(attribute, n)
        window -> :recon.proc_window(attribute, n, window)
      end

    Enum.map(results, &format_result/1)
  end

  @doc """
  Top `n` processes by memory usage (bytes).

  See `top/3` for options.
  """
  @spec top_memory(pos_integer(), keyword()) :: [result()]
  def top_memory(n \\ 10, opts \\ []), do: top(:memory, n, opts)

  @doc """
  Top `n` processes by reduction count.

  See `top/3` for options.
  """
  @spec top_reductions(n :: pos_integer(), keyword()) :: [result()]
  def top_reductions(n \\ 10, opts \\ []), do: top(:reductions, n, opts)

  @doc """
  Top `n` processes by message queue length.

  See `top/3` for options.
  """
  @spec top_message_queue(pos_integer(), keyword()) :: [result()]
  def top_message_queue(n \\ 10, opts \\ []), do: top(:message_queue_len, n, opts)

  @doc """
  Top `n` processes by total heap size (words).

  See `top/3` for options.
  """
  @spec top_total_heap(pos_integer(), keyword()) :: [result()]
  def top_total_heap(n \\ 10, opts \\ []), do: top(:total_heap_size, n, opts)

  @doc """
  Top `n` processes by heap size (words).

  See `top/3` for options.
  """
  @spec top_heap(pos_integer(), keyword()) :: [result()]
  def top_heap(n \\ 10, opts \\ []), do: top(:heap_size, n, opts)

  @doc """
  Top `n` processes by stack size (words).

  See `top/3` for options.
  """
  @spec top_stack(pos_integer(), keyword()) :: [result()]
  def top_stack(n \\ 10, opts \\ []), do: top(:stack_size, n, opts)

  defp format_result({pid, value, info_list}) do
    {name, props} = extract_name(info_list)

    %{
      pid: pid,
      value: value,
      name: name,
      initial_call: Keyword.get(props, :initial_call),
      current_function: Keyword.get(props, :current_function)
    }
  end

  # recon info_list format: [registered_name_atom | {key, val} tuples]
  # If the process is registered, the first element is a bare atom.
  defp extract_name([name | rest]) when is_atom(name), do: {name, rest}
  defp extract_name(props), do: {nil, props}
end
