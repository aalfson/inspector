defmodule Inspector.ProcessTest do
  use ExUnit.Case, async: true

  alias Inspector.Process, as: Proc
  alias Inspector.TestProcesses

  describe "info/1" do
    test "returns categorized map for a live GenServer" do
      {:ok, pid} = TestProcesses.start_genserver(%{x: 1})

      assert {:ok, result} = Proc.info(pid)

      assert Map.has_key?(result, :meta)
      assert Map.has_key?(result, :signals)
      assert Map.has_key?(result, :location)
      assert Map.has_key?(result, :memory_used)
      assert Map.has_key?(result, :work)

      assert is_map(result.meta)
      assert is_integer(result.memory_used.memory)
      assert is_integer(result.work.reductions)

      GenServer.stop(pid)
    end

    test "returns initial_call in location" do
      {:ok, pid} = TestProcesses.start_genserver(:state)
      assert {:ok, result} = Proc.info(pid)

      assert {_m, _f, _a} = result.location.initial_call

      GenServer.stop(pid)
    end

    test "returns {:error, :not_found} for a dead pid" do
      dead = TestProcesses.spawn_dead()
      assert {:error, :not_found} = Proc.info(dead)
    end

    test "accepts tuple PID format" do
      {:ok, pid} = TestProcesses.start_genserver(:state)

      [a, b, c] =
        pid
        |> inspect()
        |> String.trim_leading("#PID<")
        |> String.trim_trailing(">")
        |> String.split(".")
        |> Enum.map(&String.to_integer/1)

      assert {:ok, result} = Proc.info({a, b, c})
      assert Map.has_key?(result, :meta)

      GenServer.stop(pid)
    end
  end

  describe "mailbox/2" do
    test "returns messages from a process" do
      pid = TestProcesses.spawn_with_mailbox(3)

      assert {:ok, result} = Proc.mailbox(pid)

      assert result.total == 3
      assert result.returned == 3
      assert result.truncated == false
      assert result.messages == [{:msg, 1}, {:msg, 2}, {:msg, 3}]

      Process.exit(pid, :kill)
    end

    test "respects :limit option" do
      pid = TestProcesses.spawn_with_mailbox(10)

      assert {:ok, result} = Proc.mailbox(pid, limit: 3)

      assert result.total == 10
      assert result.returned == 3
      assert result.truncated == true
      assert result.messages == [{:msg, 1}, {:msg, 2}, {:msg, 3}]

      Process.exit(pid, :kill)
    end

    test "returns truncated: true when messages exceed default limit" do
      pid = TestProcesses.spawn_with_mailbox(150)

      assert {:ok, result} = Proc.mailbox(pid)

      assert result.total == 150
      assert result.returned == 100
      assert result.truncated == true

      Process.exit(pid, :kill)
    end

    test "returns {:error, :not_found} for dead pid" do
      dead = TestProcesses.spawn_dead()
      assert {:error, :not_found} = Proc.mailbox(dead)
    end

    test "returns {:error, :mailbox_too_large} when queue exceeds hard cap" do
      pid = TestProcesses.spawn_with_mailbox(1_001)

      assert {:error, :mailbox_too_large} = Proc.mailbox(pid)

      Process.exit(pid, :kill)
    end

    test "bypasses hard cap with force: true" do
      pid = TestProcesses.spawn_with_mailbox(1_001)

      assert {:ok, result} = Proc.mailbox(pid, force: true, limit: 5)

      assert result.total == 1_001
      assert result.returned == 5
      assert result.truncated == true

      Process.exit(pid, :kill)
    end

    test "returns empty messages for process with no mail" do
      pid = TestProcesses.spawn_idle()

      assert {:ok, result} = Proc.mailbox(pid)

      assert result.total == 0
      assert result.returned == 0
      assert result.truncated == false
      assert result.messages == []

      Process.exit(pid, :kill)
    end
  end

  describe "state/2" do
    test "returns GenServer state" do
      {:ok, pid} = TestProcesses.start_genserver(%{count: 42})

      assert {:ok, %{count: 42}} = Proc.state(pid)

      GenServer.stop(pid)
    end

    test "returns updated state after cast" do
      {:ok, pid} = TestProcesses.start_genserver(:initial)
      GenServer.cast(pid, {:set_state, :updated})
      Process.sleep(10)

      assert {:ok, :updated} = Proc.state(pid)

      GenServer.stop(pid)
    end

    test "returns {:error, _} for a non-OTP process" do
      pid = TestProcesses.spawn_idle()

      assert {:error, _reason} = Proc.state(pid, timeout: 500)

      Process.exit(pid, :kill)
    end

    test "returns {:error, _} for a dead pid" do
      dead = TestProcesses.spawn_dead()

      assert {:error, _reason} = Proc.state(dead, timeout: 500)
    end

    test "respects custom timeout" do
      {:ok, pid} = TestProcesses.start_genserver(:state)

      assert {:ok, :state} = Proc.state(pid, timeout: 30_000)

      GenServer.stop(pid)
    end
  end
end
