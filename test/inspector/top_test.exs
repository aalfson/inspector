defmodule Inspector.TopTest do
  use ExUnit.Case, async: true

  alias Inspector.Top

  describe "top/3" do
    test "returns list of maps with expected shape" do
      results = Top.top(:memory, 5)

      assert is_list(results)
      assert length(results) <= 5

      for entry <- results do
        assert is_pid(entry.pid)
        assert is_integer(entry.value)
        assert entry.value >= 0
        assert Map.has_key?(entry, :name)
        assert Map.has_key?(entry, :initial_call)
        assert Map.has_key?(entry, :current_function)
      end
    end

    test "results are sorted descending by value" do
      results = Top.top(:memory, 10)
      values = Enum.map(results, & &1.value)

      assert values == Enum.sort(values, :desc)
    end

    test "n parameter limits result count" do
      results = Top.top(:memory, 3)
      assert length(results) <= 3
    end

    test "returns initial_call and current_function as MFA tuples" do
      results = Top.top(:reductions, 5)

      for entry <- results do
        assert {_m, _f, _a} = entry.initial_call
        assert {_m, _f, _a} = entry.current_function
      end
    end

    test "registered processes have a name" do
      results = Top.top(:memory, 50)
      named = Enum.filter(results, & &1.name)

      # There should be at least some registered processes in the system
      assert length(named) > 0

      for entry <- named do
        assert is_atom(entry.name)
      end
    end

    test "unregistered processes have nil name" do
      results = Top.top(:memory, 50)
      unnamed = Enum.filter(results, &is_nil(&1.name))

      assert length(unnamed) > 0
    end

    test "with window option returns delta-based results" do
      results = Top.top(:reductions, 5, window: 100)

      assert is_list(results)
      assert length(results) <= 5

      for entry <- results do
        assert is_pid(entry.pid)
        assert is_integer(entry.value)
      end
    end
  end

  describe "convenience functions" do
    test "top_memory returns results for memory attribute" do
      results = Top.top_memory(3)
      assert is_list(results)
      assert length(results) <= 3
    end

    test "top_reductions returns results" do
      results = Top.top_reductions(3)
      assert is_list(results)
      assert length(results) <= 3
    end

    test "top_message_queue returns results" do
      results = Top.top_message_queue(3)
      assert is_list(results)
      assert length(results) <= 3
    end

    test "top_total_heap returns results" do
      results = Top.top_total_heap(3)
      assert is_list(results)
      assert length(results) <= 3
    end

    test "top_heap returns results" do
      results = Top.top_heap(3)
      assert is_list(results)
      assert length(results) <= 3
    end

    test "top_stack returns results" do
      results = Top.top_stack(3)
      assert is_list(results)
      assert length(results) <= 3
    end

    test "convenience functions accept window option" do
      results = Top.top_memory(3, window: 100)
      assert is_list(results)
      assert length(results) <= 3
    end

    test "default n is 10" do
      results = Top.top_memory()
      assert length(results) <= 10
    end
  end
end
