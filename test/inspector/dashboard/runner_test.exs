defmodule Inspector.Dashboard.RunnerTest do
  use ExUnit.Case, async: true

  alias Inspector.Dashboard.Runner

  describe "execute/3 — process group" do
    test "process_info on a live process" do
      pid = spawn(fn -> Process.sleep(:infinity) end)

      assert {:ok, result} = Runner.execute(:process_info, node(), %{"pid" => inspect(pid)})
      assert is_binary(result)
      assert result =~ "meta"

      Process.exit(pid, :kill)
    end

    test "mailbox on a live process" do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      send(pid, :hello)

      assert {:ok, result} = Runner.execute(:mailbox, node(), %{"pid" => inspect(pid)})
      assert result =~ ":hello"

      Process.exit(pid, :kill)
    end

    test "state on a GenServer" do
      {:ok, pid} = Inspector.TestProcesses.start_genserver(:test_state)

      assert {:ok, result} = Runner.execute(:state, node(), %{"pid" => inspect(pid)})
      assert result =~ ":test_state"

      GenServer.stop(pid)
    end
  end

  describe "execute/3 — top group" do
    test "top_memory returns results" do
      assert {:ok, result} = Runner.execute(:top_memory, node(), %{"n" => "5"})
      assert is_binary(result)
    end

    test "top_reductions with default n" do
      assert {:ok, result} = Runner.execute(:top_reductions, node(), %{})
      assert is_binary(result)
    end
  end

  describe "execute/3 — aggregate group" do
    test "current_functions returns results" do
      assert {:ok, result} = Runner.execute(:current_functions, node(), %{})
      assert is_binary(result)
      assert result =~ "function"
    end

    test "initial_calls returns results" do
      assert {:ok, result} = Runner.execute(:initial_calls, node(), %{})
      assert is_binary(result)
    end
  end

  describe "execute/3 — error handling" do
    test "unknown function key" do
      assert {:error, "Unknown function: bogus"} = Runner.execute(:bogus, node(), %{})
    end
  end

  describe "parse_params/2" do
    test "parses number params" do
      assert %{n: 5} = Runner.parse_params(:top_memory, %{"n" => "5"})
    end

    test "parses text params" do
      assert %{pid: "0.123.0"} = Runner.parse_params(:process_info, %{"pid" => "0.123.0"})
    end

    test "ignores blank params" do
      assert %{} = Runner.parse_params(:top_memory, %{"n" => "", "window" => ""})
    end

    test "ignores invalid numbers" do
      assert %{} = Runner.parse_params(:top_memory, %{"n" => "abc"})
    end

    test "returns empty map for unknown function" do
      assert %{} = Runner.parse_params(:bogus, %{"n" => "5"})
    end
  end

  describe "format_result/1" do
    test "formats simple terms" do
      assert Runner.format_result(:ok) == ":ok"
    end

    test "formats complex terms with pretty print" do
      result = Runner.format_result(%{a: 1, b: [1, 2, 3]})
      assert is_binary(result)
      assert result =~ "a:"
    end
  end
end
