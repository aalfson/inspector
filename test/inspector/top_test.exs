defmodule Inspector.TopTest do
  use ExUnit.Case, async: true

  alias Inspector.Top

  describe "top/3" do
    test "returns {:ok, list} of maps with expected shape" do
      assert {:ok, results} = Top.top(:memory, 5)

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
      assert {:ok, results} = Top.top(:memory, 10)
      values = Enum.map(results, & &1.value)

      assert values == Enum.sort(values, :desc)
    end

    test "n parameter limits result count" do
      assert {:ok, results} = Top.top(:memory, 3)
      assert length(results) <= 3
    end

    test "returns initial_call and current_function as MFA tuples" do
      assert {:ok, results} = Top.top(:reductions, 5)

      for entry <- results do
        assert {_m, _f, _a} = entry.initial_call
        assert {_m, _f, _a} = entry.current_function
      end
    end

    test "registered processes have a name" do
      assert {:ok, results} = Top.top(:memory, 50)
      named = Enum.filter(results, & &1.name)

      assert length(named) > 0

      for entry <- named do
        assert is_atom(entry.name)
      end
    end

    test "unregistered processes have nil name" do
      assert {:ok, results} = Top.top(:memory, 50)
      unnamed = Enum.filter(results, &is_nil(&1.name))

      assert length(unnamed) > 0
    end

    test "with window option returns delta-based results" do
      assert {:ok, results} = Top.top(:reductions, 5, window: 100)

      assert length(results) <= 5

      for entry <- results do
        assert is_pid(entry.pid)
        assert is_integer(entry.value)
      end
    end
  end

  describe "validation" do
    test "returns error for invalid attribute" do
      assert {:error, {:invalid_attribute, :garbage}} = Top.top(:garbage, 5)
    end

    test "returns error for non-positive n" do
      assert {:error, :invalid_count} = Top.top(:memory, 0, [])
      assert {:error, :invalid_count} = Top.top(:memory, -1, [])
    end

    test "returns error for non-integer n" do
      assert {:error, :invalid_count} = Top.top(:memory, "5", [])
    end

    test "returns error for non-positive window" do
      assert {:error, :invalid_window} = Top.top(:memory, 5, window: 0)
      assert {:error, :invalid_window} = Top.top(:memory, 5, window: -100)
    end

    test "returns error for non-integer window" do
      assert {:error, :invalid_window} = Top.top(:memory, 5, window: "100")
    end

    test "returns error when window exceeds cap" do
      assert {:error, :window_too_large} = Top.top(:memory, 5, window: 60_000)
    end

    test "force: true bypasses window cap" do
      # Use a small window that's just over the cap to avoid blocking long
      assert {:ok, _results} = Top.top(:reductions, 3, window: 31_000, force: true)
    end
  end

  describe "ergonomic call patterns" do
    test "top(attribute) defaults to n=10" do
      assert {:ok, results} = Top.top(:memory)
      assert length(results) <= 10
    end

    test "top(attribute, n) with integer n" do
      assert {:ok, results} = Top.top(:memory, 3)
      assert length(results) <= 3
    end

    test "top(attribute, opts) with keyword list" do
      assert {:ok, results} = Top.top(:memory, window: 100)
      assert length(results) <= 10
    end

    test "top(attribute, n, opts) full form" do
      assert {:ok, results} = Top.top(:memory, 3, window: 100)
      assert length(results) <= 3
    end
  end

  describe "convenience functions" do
    test "top_memory returns results" do
      assert {:ok, results} = Top.top_memory(3)
      assert length(results) <= 3
    end

    test "top_reductions returns results" do
      assert {:ok, results} = Top.top_reductions(3)
      assert length(results) <= 3
    end

    test "top_message_queue returns results" do
      assert {:ok, results} = Top.top_message_queue(3)
      assert length(results) <= 3
    end

    test "top_total_heap returns results" do
      assert {:ok, results} = Top.top_total_heap(3)
      assert length(results) <= 3
    end

    test "top_heap returns results" do
      assert {:ok, results} = Top.top_heap(3)
      assert length(results) <= 3
    end

    test "top_stack returns results" do
      assert {:ok, results} = Top.top_stack(3)
      assert length(results) <= 3
    end

    test "convenience functions accept window option" do
      assert {:ok, results} = Top.top_memory(3, window: 100)
      assert length(results) <= 3
    end

    test "convenience functions default to n=10" do
      assert {:ok, results} = Top.top_memory()
      assert length(results) <= 10
    end

    test "convenience functions accept opts without n" do
      assert {:ok, results} = Top.top_memory(window: 100)
      assert length(results) <= 10
    end
  end
end
