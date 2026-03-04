defmodule Inspector.AggregateTest do
  use ExUnit.Case, async: true

  alias Inspector.Aggregate
  alias Inspector.TestProcesses

  describe "current_functions/1" do
    test "groups and counts by current function" do
      pids = for _ <- 1..5, do: TestProcesses.spawn_idle()

      results = Aggregate.current_functions(pids)

      assert [%{function: {_, _, _}, count: 5}] = results

      Enum.each(pids, &Process.exit(&1, :kill))
    end

    test "results sorted descending by count" do
      idle_pids = for _ <- 1..3, do: TestProcesses.spawn_idle()

      genserver_pids =
        for _ <- 1..2 do
          {:ok, pid} = TestProcesses.start_genserver(:state)
          pid
        end

      results = Aggregate.current_functions(idle_pids ++ genserver_pids)

      counts = Enum.map(results, & &1.count)
      assert counts == Enum.sort(counts, :desc)

      Enum.each(idle_pids, &Process.exit(&1, :kill))
      Enum.each(genserver_pids, &GenServer.stop/1)
    end

    test "skips dead pids" do
      live = TestProcesses.spawn_idle()
      dead = TestProcesses.spawn_dead()

      results = Aggregate.current_functions([live, dead])

      total = Enum.reduce(results, 0, fn %{count: c}, acc -> acc + c end)
      assert total == 1

      Process.exit(live, :kill)
    end

    test "accepts mixed PID formats" do
      pid = TestProcesses.spawn_idle()

      [a, b, c] =
        pid
        |> inspect()
        |> String.trim_leading("#PID<")
        |> String.trim_trailing(">")
        |> String.split(".")
        |> Enum.map(&String.to_integer/1)

      inputs = [pid, {a, b, c}, "<#{a}.#{b}.#{c}>"]

      results = Aggregate.current_functions(inputs)

      total = Enum.reduce(results, 0, fn %{count: c}, acc -> acc + c end)
      assert total == 3

      Process.exit(pid, :kill)
    end

    test "returns empty list for empty input" do
      assert [] = Aggregate.current_functions([])
    end

    test "skips invalid pid inputs" do
      pid = TestProcesses.spawn_idle()

      results = Aggregate.current_functions([pid, "not_a_pid", 12345])

      total = Enum.reduce(results, 0, fn %{count: c}, acc -> acc + c end)
      assert total == 1

      Process.exit(pid, :kill)
    end

    test "respects :max_concurrency option" do
      pids = for _ <- 1..10, do: TestProcesses.spawn_idle()

      results = Aggregate.current_functions(pids, max_concurrency: 2)

      assert [%{count: 10}] = results

      Enum.each(pids, &Process.exit(&1, :kill))
    end

    test "respects :timeout option" do
      pids = for _ <- 1..5, do: TestProcesses.spawn_idle()

      results = Aggregate.current_functions(pids, timeout: 30_000)

      assert [%{count: 5}] = results

      Enum.each(pids, &Process.exit(&1, :kill))
    end
  end

  describe "initial_calls/1" do
    test "groups and counts by initial call" do
      pids = for _ <- 1..4, do: TestProcesses.spawn_idle()

      results = Aggregate.initial_calls(pids)

      assert [%{function: {_, _, _}, count: 4}] = results

      Enum.each(pids, &Process.exit(&1, :kill))
    end

    test "results sorted descending by count" do
      idle_pids = for _ <- 1..3, do: TestProcesses.spawn_idle()

      genserver_pids =
        for _ <- 1..2 do
          {:ok, pid} = TestProcesses.start_genserver(:state)
          pid
        end

      results = Aggregate.initial_calls(idle_pids ++ genserver_pids)

      counts = Enum.map(results, & &1.count)
      assert counts == Enum.sort(counts, :desc)

      Enum.each(idle_pids, &Process.exit(&1, :kill))
      Enum.each(genserver_pids, &GenServer.stop/1)
    end

    test "skips dead pids" do
      live = TestProcesses.spawn_idle()
      dead = TestProcesses.spawn_dead()

      results = Aggregate.initial_calls([live, dead])

      total = Enum.reduce(results, 0, fn %{count: c}, acc -> acc + c end)
      assert total == 1

      Process.exit(live, :kill)
    end

    test "returns empty list for empty input" do
      assert [] = Aggregate.initial_calls([])
    end
  end

  describe "list_pids/0" do
    test "returns a list of pids" do
      pids = Aggregate.list_pids()

      assert is_list(pids)
      assert length(pids) > 0
      assert Enum.all?(pids, &is_pid/1)
    end

    test "pipes into current_functions" do
      results = Aggregate.list_pids() |> Aggregate.current_functions()

      assert length(results) > 0
    end

    test "pipes into initial_calls" do
      results = Aggregate.list_pids() |> Aggregate.initial_calls()

      assert length(results) > 0
    end
  end
end
