defmodule Inspector.Process do
  @moduledoc """
  Single-process inspection functions.

  Wraps `:recon.info/1`, `:erlang.process_info/2`, and `:recon.get_state/2`
  to provide structured, safe access to process internals.
  """

  alias Inspector.Utils

  @default_mailbox_limit 100
  @mailbox_hard_cap 1_000
  @default_state_timeout 10_000

  @doc """
  Returns detailed info about a process as a categorized map.

  Wraps `:recon.info/1` and restructures the result into nested maps
  with keys: `:meta`, `:signals`, `:location`, `:memory_used`, `:work`.

  Returns `{:error, :not_found}` if the process is dead or doesn't exist.

  ## Examples

      iex> {:ok, pid} = GenServer.start(fn -> {:ok, :state} end, [])
      iex> %{meta: meta} = Inspector.Process.info(pid)
      iex> is_map(meta)
      true

  """
  @spec info(Utils.pid_input()) :: map() | {:error, :not_found}
  def info(pid_input) do
    pid = Utils.to_pid(pid_input)

    case :recon.info(pid) do
      result when is_list(result) ->
        if Enum.any?(result, fn {_cat, val} -> val == :undefined end) do
          {:error, :not_found}
        else
          result
          |> Enum.map(fn {category, kv_list} -> {category, Map.new(kv_list)} end)
          |> Map.new()
        end

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns messages from a process's mailbox with safety limits.

  Checks `:message_queue_len` first. If the queue exceeds #{@mailbox_hard_cap}
  messages, returns `{:error, :mailbox_too_large}` unless `force: true` is passed.

  Returns a map with `:total`, `:returned`, `:truncated`, and `:messages` keys.
  Returns `{:error, :not_found}` if the process is dead.

  ## Options

    * `:limit` — max messages to return (default: #{@default_mailbox_limit})
    * `:force` — bypass the #{@mailbox_hard_cap}-message hard cap (default: `false`)

  ## Examples

      iex> pid = spawn(fn -> receive do :stop -> :ok end end)
      iex> send(pid, :hello)
      iex> %{total: 1, messages: [:hello]} = Inspector.Process.mailbox(pid)

  """
  @spec mailbox(Utils.pid_input(), keyword()) ::
          map() | {:error, :not_found | :mailbox_too_large}
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

        %{
          total: total,
          returned: length(returned),
          truncated: total > limit,
          messages: returned
        }
    end
  end

  @doc """
  Returns the internal state of an OTP process.

  Wraps `:recon.get_state/2`. Works with GenServer, gen_statem, and other
  OTP-compatible processes.

  Returns `{:error, reason}` if the process doesn't respond within the timeout
  or is not an OTP process.

  ## Options

    * `:timeout` — milliseconds to wait (default: #{@default_state_timeout})

  ## Examples

      iex> {:ok, pid} = GenServer.start(fn -> {:ok, %{count: 0}} end, [])
      iex> Inspector.Process.state(pid)
      %{count: 0}

  """
  @spec state(Utils.pid_input(), keyword()) :: term() | {:error, term()}
  def state(pid_input, opts \\ []) do
    pid = Utils.to_pid(pid_input)
    timeout = Keyword.get(opts, :timeout, @default_state_timeout)

    :recon.get_state(pid, timeout)
  catch
    :exit, reason -> {:error, reason}
  end
end
