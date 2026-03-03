defmodule Inspector.Process do
  @moduledoc """
  Single-process inspection functions.

  Wraps `:recon.info/1`, `:erlang.process_info/2`, and `:recon.get_state/2`
  to provide structured, safe access to process internals.

  All functions return `{:ok, result}` on success or `{:error, reason}` on failure.
  """

  alias Inspector.Utils

  @default_mailbox_limit 100
  @mailbox_hard_cap 1_000
  @default_state_timeout 10_000

  @doc """
  Returns detailed info about a process as a categorized map.

  Wraps `:recon.info/1` and restructures the result into nested maps
  with keys: `:meta`, `:signals`, `:location`, `:memory_used`, `:work`.

  ## Return shape

      {:ok, %{
        meta: %{registered_name: atom(), status: atom(), group_leader: pid(), dictionary: list()},
        signals: %{links: [pid()], monitors: list(), monitored_by: [pid()], trap_exit: boolean()},
        location: %{initial_call: {module(), atom(), arity()}, current_stacktrace: list()},
        memory_used: %{memory: integer(), message_queue_len: integer(), heap_size: integer(),
                       total_heap_size: integer(), garbage_collection: list()},
        work: %{reductions: integer()}
      }}

  """
  @spec info(Utils.pid_input()) :: {:ok, map()} | {:error, :not_found}
  def info(pid_input) do
    pid = Utils.to_pid(pid_input)

    case :recon.info(pid) do
      result when is_list(result) ->
        if Enum.any?(result, fn {_cat, val} -> val == :undefined end) do
          {:error, :not_found}
        else
          info_map =
            result
            |> Enum.map(fn {category, kv_list} -> {category, Map.new(kv_list)} end)
            |> Map.new()

          {:ok, info_map}
        end

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns messages from a process's mailbox with safety limits.

  Checks `:message_queue_len` first. If the queue exceeds #{@mailbox_hard_cap}
  messages, returns `{:error, :mailbox_too_large}` unless `force: true` is passed.

  ## Options

    * `:limit` — max messages to return (default: #{@default_mailbox_limit})
    * `:force` — bypass the #{@mailbox_hard_cap}-message hard cap (default: `false`)

  ## Return shape

      {:ok, %{
        total: integer(),       # actual queue length at time of check
        returned: integer(),    # number of messages included in :messages
        truncated: boolean(),   # true when total > limit
        messages: [term()]      # first :limit messages from the mailbox
      }}

  ## Safety

  **Warning:** `force: true` bypasses the hard cap but `:erlang.process_info(pid, :messages)`
  still copies the **entire** mailbox into the calling process's heap before `Enum.take`
  truncates it. On a process with millions of messages this can consume gigabytes of
  memory and OOM the caller. Use `force: true` only when you understand the mailbox size
  and accept the risk.

  """
  @spec mailbox(Utils.pid_input(), keyword()) ::
          {:ok, map()} | {:error, :not_found | :mailbox_too_large}
  def mailbox(pid_input, opts \\ []) do
    pid = Utils.to_pid(pid_input)
    limit = Keyword.get(opts, :limit, @default_mailbox_limit)
    force = Keyword.get(opts, :force, false)

    case :erlang.process_info(pid, :message_queue_len) do
      result when result in [nil, :undefined] ->
        {:error, :not_found}

      {:message_queue_len, total} when total > @mailbox_hard_cap and not force ->
        {:error, :mailbox_too_large}

      {:message_queue_len, total} ->
        {:messages, messages} = :erlang.process_info(pid, :messages)
        returned = Enum.take(messages, limit)

        {:ok,
         %{
           total: total,
           returned: length(returned),
           truncated: total > limit,
           messages: returned
         }}
    end
  end

  @doc """
  Returns the internal state of an OTP process.

  Wraps `:recon.get_state/2`. Works with GenServer, gen_statem, and other
  OTP-compatible processes.

  ## Options

    * `:timeout` — milliseconds to wait (default: #{@default_state_timeout})

  ## Examples

      iex> {:ok, pid} = GenServer.start_link(fn -> {:ok, %{count: 0}} end, [])
      iex> {:ok, state} = Inspector.Process.state(pid)
      iex> state
      %{count: 0}

  """
  @spec state(Utils.pid_input(), keyword()) :: {:ok, term()} | {:error, term()}
  def state(pid_input, opts \\ []) do
    pid = Utils.to_pid(pid_input)
    timeout = Keyword.get(opts, :timeout, @default_state_timeout)

    {:ok, :recon.get_state(pid, timeout)}
  catch
    :exit, reason -> {:error, reason}
  end
end
