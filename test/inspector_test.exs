defmodule InspectorTest do
  use ExUnit.Case, async: true

  alias Inspector.TestProcesses

  describe "process_info/1" do
    test "returns process info via facade" do
      {:ok, pid} = TestProcesses.start_genserver(:state)

      assert {:ok, info} = Inspector.process_info(pid)
      assert is_map(info.meta)
      assert is_integer(info.work.reductions)

      GenServer.stop(pid)
    end
  end

  describe "mailbox/2" do
    test "returns mailbox via facade" do
      pid = TestProcesses.spawn_with_mailbox(3)

      assert {:ok, result} = Inspector.mailbox(pid)
      assert result.total == 3
      assert length(result.messages) == 3

      Process.exit(pid, :kill)
    end

    test "accepts opts" do
      pid = TestProcesses.spawn_with_mailbox(10)

      assert {:ok, result} = Inspector.mailbox(pid, limit: 2)
      assert result.returned == 2

      Process.exit(pid, :kill)
    end
  end

  describe "state/2" do
    test "returns state via facade" do
      {:ok, pid} = TestProcesses.start_genserver(%{v: 1})

      assert {:ok, %{v: 1}} = Inspector.state(pid)

      GenServer.stop(pid)
    end
  end

  describe "top functions" do
    test "top/1 returns results" do
      assert {:ok, results} = Inspector.top(:memory)
      assert is_list(results)
    end

    test "top/2 with integer n" do
      assert {:ok, results} = Inspector.top(:memory, 3)
      assert length(results) <= 3
    end

    test "top/2 with opts" do
      assert {:ok, results} = Inspector.top(:reductions, window: 100)
      assert is_list(results)
    end

    test "top_memory delegates correctly" do
      assert {:ok, results} = Inspector.top_memory()
      assert length(results) <= 10
    end

    test "top_memory/1 with integer" do
      assert {:ok, results} = Inspector.top_memory(3)
      assert length(results) <= 3
    end

    test "top_memory/1 with opts" do
      assert {:ok, results} = Inspector.top_memory(window: 100)
      assert length(results) <= 10
    end

    test "top_reductions delegates" do
      assert {:ok, _} = Inspector.top_reductions(3)
    end

    test "top_message_queue delegates" do
      assert {:ok, _} = Inspector.top_message_queue(3)
    end

    test "top_total_heap delegates" do
      assert {:ok, _} = Inspector.top_total_heap(3)
    end

    test "top_heap delegates" do
      assert {:ok, _} = Inspector.top_heap(3)
    end

    test "top_stack delegates" do
      assert {:ok, _} = Inspector.top_stack(3)
    end
  end

  describe "aggregate functions" do
    test "list_pids returns system pids" do
      pids = Inspector.list_pids()
      assert length(pids) > 0
      assert Enum.all?(pids, &is_pid/1)
    end

    test "current_functions via facade" do
      pids = for _ <- 1..3, do: TestProcesses.spawn_idle()

      results = Inspector.current_functions(pids)
      assert [%{count: 3}] = results

      Enum.each(pids, &Process.exit(&1, :kill))
    end

    test "initial_calls via facade" do
      pids = for _ <- 1..3, do: TestProcesses.spawn_idle()

      results = Inspector.initial_calls(pids)
      assert [%{count: 3}] = results

      Enum.each(pids, &Process.exit(&1, :kill))
    end

    test "list_pids pipes into current_functions" do
      results = Inspector.list_pids() |> Inspector.current_functions()
      assert length(results) > 0
    end

    test "aggregate functions accept opts" do
      pids = for _ <- 1..3, do: TestProcesses.spawn_idle()

      results = Inspector.current_functions(pids, max_concurrency: 2, timeout: 30_000)
      assert [%{count: 3}] = results

      Enum.each(pids, &Process.exit(&1, :kill))
    end
  end

  describe "error propagation through facade" do
    test "process_info returns error for dead pid" do
      dead = TestProcesses.spawn_dead()
      assert {:error, :not_found} = Inspector.process_info(dead)
    end

    test "mailbox returns error for dead pid" do
      dead = TestProcesses.spawn_dead()
      assert {:error, :not_found} = Inspector.mailbox(dead)
    end

    test "state returns error for non-OTP process" do
      pid = TestProcesses.spawn_idle()
      assert {:error, _} = Inspector.state(pid, timeout: 500)
      Process.exit(pid, :kill)
    end

    test "top returns error for invalid attribute" do
      assert {:error, {:invalid_attribute, :bogus}} = Inspector.top(:bogus)
    end

    test "top/2 returns error for n=0" do
      assert {:error, :invalid_count} = Inspector.top(:memory, 0)
    end

    test "top/2 returns error for negative n" do
      assert {:error, :invalid_count} = Inspector.top(:memory, -1)
    end

    test "top/3 returns error for window exceeding cap" do
      assert {:error, :window_too_large} = Inspector.top(:memory, 5, window: 60_000)
    end

    test "top_memory returns error for invalid n" do
      assert {:error, :invalid_count} = Inspector.top_memory(0)
    end
  end

  describe "end-to-end: PID format interop" do
    test "facade functions accept string PIDs" do
      {:ok, pid} = TestProcesses.start_genserver(:test_state)
      str = inspect(pid)

      assert {:ok, _info} = Inspector.process_info(str)
      assert {:ok, _mailbox} = Inspector.mailbox(str)
      assert {:ok, :test_state} = Inspector.state(str)

      GenServer.stop(pid)
    end

    test "facade functions accept tuple PIDs" do
      {:ok, pid} = TestProcesses.start_genserver(:test_state)

      [a, b, c] =
        pid |> inspect() |> String.trim_leading("#PID<") |> String.trim_trailing(">")
        |> String.split(".") |> Enum.map(&String.to_integer/1)

      assert {:ok, _info} = Inspector.process_info({a, b, c})
      assert {:ok, :test_state} = Inspector.state({a, b, c})

      GenServer.stop(pid)
    end
  end
end
