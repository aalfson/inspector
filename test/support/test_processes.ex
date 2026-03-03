defmodule Inspector.TestProcesses do
  @moduledoc false

  use GenServer

  # -- Client API --

  @doc """
  Starts a GenServer with the given state. Returns `{:ok, pid}`.
  """
  def start_genserver(state, opts \\ []) do
    GenServer.start(__MODULE__, state, opts)
  end

  @doc """
  Spawns a bare process that blocks in receive forever. Returns pid.
  """
  def spawn_idle do
    spawn(fn -> idle_loop() end)
  end

  @doc """
  Spawns a process and sends it `count` messages. Returns pid.
  """
  def spawn_with_mailbox(count) do
    pid = spawn(fn -> idle_loop() end)
    for i <- 1..count, do: send(pid, {:msg, i})
    pid
  end

  @doc """
  Spawns a process that exits immediately. Waits for it to die, returns the dead pid.
  """
  def spawn_dead do
    pid = spawn(fn -> :ok end)
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _} -> pid
    end
  end

  # -- GenServer callbacks --

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:set_state, new_state}, _state), do: {:noreply, new_state}

  # -- Helpers --

  defp idle_loop do
    receive do
      :stop -> :ok
    end
  end
end
