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

  @valid_attributes ~w(memory reductions message_queue_len total_heap_size heap_size stack_size)a
  @max_window 30_000

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

    * `:window` — time window in ms for delta-based measurement (max #{@max_window}ms)
    * `:force` — bypass the #{@max_window}ms window cap (default: `false`)

  ## Return shape

      {:ok, [
        %{
          pid: #PID<0.123.0>,
          value: 45678,
          name: :my_server,             # registered name or nil
          initial_call: {M, F, A},
          current_function: {M, F, A}
        },
        ...
      ]}

  ## Errors

    * `{:error, {:invalid_attribute, atom()}}` — unsupported attribute
    * `{:error, :invalid_count}` — n is not a positive integer
    * `{:error, :invalid_window}` — window is not a positive integer
    * `{:error, :window_too_large}` — window exceeds #{@max_window}ms (use `force: true`)

  """
  @spec top(atom(), pos_integer(), keyword()) ::
          {:ok, [result()]} | {:error, term()}
  def top(attribute, n, opts)

  def top(attribute, n, opts) when is_integer(n) and n > 0 and is_list(opts) do
    with :ok <- validate_attribute(attribute),
         :ok <- validate_window(opts) do
      results =
        case Keyword.get(opts, :window) do
          nil -> :recon.proc_count(attribute, n)
          window -> :recon.proc_window(attribute, n, window)
        end

      {:ok, Enum.map(results, &format_result/1)}
    end
  end

  def top(_attribute, n, _opts) when not is_integer(n) or n <= 0 do
    {:error, :invalid_count}
  end

  @doc false
  def top(attribute), do: top(attribute, 10, [])
  @doc false
  def top(attribute, n) when is_integer(n) and n > 0, do: top(attribute, n, [])
  @doc false
  def top(attribute, opts) when is_list(opts), do: top(attribute, 10, opts)

  @doc """
  Top `n` processes by memory usage (bytes).

  See `top/3` for options and return shape.
  """
  @spec top_memory(pos_integer(), keyword()) :: {:ok, [result()]} | {:error, term()}
  def top_memory, do: top(:memory, 10, [])
  def top_memory(n) when is_integer(n), do: top(:memory, n, [])
  def top_memory(opts) when is_list(opts), do: top(:memory, 10, opts)
  def top_memory(n, opts) when is_integer(n), do: top(:memory, n, opts)

  @doc """
  Top `n` processes by reduction count.

  See `top/3` for options and return shape.
  """
  @spec top_reductions(pos_integer(), keyword()) :: {:ok, [result()]} | {:error, term()}
  def top_reductions, do: top(:reductions, 10, [])
  def top_reductions(n) when is_integer(n), do: top(:reductions, n, [])
  def top_reductions(opts) when is_list(opts), do: top(:reductions, 10, opts)
  def top_reductions(n, opts) when is_integer(n), do: top(:reductions, n, opts)

  @doc """
  Top `n` processes by message queue length.

  See `top/3` for options and return shape.
  """
  @spec top_message_queue(pos_integer(), keyword()) :: {:ok, [result()]} | {:error, term()}
  def top_message_queue, do: top(:message_queue_len, 10, [])
  def top_message_queue(n) when is_integer(n), do: top(:message_queue_len, n, [])
  def top_message_queue(opts) when is_list(opts), do: top(:message_queue_len, 10, opts)
  def top_message_queue(n, opts) when is_integer(n), do: top(:message_queue_len, n, opts)

  @doc """
  Top `n` processes by total heap size (words).

  See `top/3` for options and return shape.
  """
  @spec top_total_heap(pos_integer(), keyword()) :: {:ok, [result()]} | {:error, term()}
  def top_total_heap, do: top(:total_heap_size, 10, [])
  def top_total_heap(n) when is_integer(n), do: top(:total_heap_size, n, [])
  def top_total_heap(opts) when is_list(opts), do: top(:total_heap_size, 10, opts)
  def top_total_heap(n, opts) when is_integer(n), do: top(:total_heap_size, n, opts)

  @doc """
  Top `n` processes by heap size (words).

  See `top/3` for options and return shape.
  """
  @spec top_heap(pos_integer(), keyword()) :: {:ok, [result()]} | {:error, term()}
  def top_heap, do: top(:heap_size, 10, [])
  def top_heap(n) when is_integer(n), do: top(:heap_size, n, [])
  def top_heap(opts) when is_list(opts), do: top(:heap_size, 10, opts)
  def top_heap(n, opts) when is_integer(n), do: top(:heap_size, n, opts)

  @doc """
  Top `n` processes by stack size (words).

  See `top/3` for options and return shape.
  """
  @spec top_stack(pos_integer(), keyword()) :: {:ok, [result()]} | {:error, term()}
  def top_stack, do: top(:stack_size, 10, [])
  def top_stack(n) when is_integer(n), do: top(:stack_size, n, [])
  def top_stack(opts) when is_list(opts), do: top(:stack_size, 10, opts)
  def top_stack(n, opts) when is_integer(n), do: top(:stack_size, n, opts)

  defp validate_attribute(attr) when attr in @valid_attributes, do: :ok
  defp validate_attribute(attr), do: {:error, {:invalid_attribute, attr}}

  defp validate_window(opts) do
    window = Keyword.get(opts, :window)
    force = Keyword.get(opts, :force, false)

    cond do
      is_nil(window) -> :ok
      not is_integer(window) or window <= 0 -> {:error, :invalid_window}
      window > @max_window and not force -> {:error, :window_too_large}
      true -> :ok
    end
  end

  defp format_result({pid, value, info_list}) do
    # recon info_list format (recon ~> 2.5):
    # [registered_name_atom | keyword pairs] when registered,
    # [keyword pairs] when unregistered.
    # Bare atoms are registered names; tuples are {key, val} props.
    {names, props} = Enum.split_with(info_list, &is_atom/1)

    %{
      pid: pid,
      value: value,
      name: List.first(names),
      initial_call: Keyword.get(props, :initial_call),
      current_function: Keyword.get(props, :current_function)
    }
  end
end
