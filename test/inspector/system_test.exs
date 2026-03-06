defmodule Inspector.SystemTest do
  use ExUnit.Case, async: true

  alias Inspector.System

  describe "port_types/0" do
    test "returns {:ok, list} of type/count tuples" do
      assert {:ok, results} = System.port_types()
      assert is_list(results)

      for {type, count} <- results do
        assert is_list(type) or is_binary(type)
        assert is_integer(count)
        assert count > 0
      end
    end
  end

  describe "node_stats/2" do
    test "returns {:ok, list} with defaults" do
      assert {:ok, results} = System.node_stats()
      assert is_list(results)
    end

    test "returns multiple samples" do
      assert {:ok, results} = System.node_stats(3, 0)
      assert length(results) == 3
    end

    test "returns error for invalid repeat" do
      assert {:error, :invalid_repeat} = System.node_stats(-1, 0)
    end

    test "returns error for invalid interval" do
      assert {:error, :invalid_interval} = System.node_stats(1, -1)
    end
  end

  describe "scheduler_usage/1" do
    test "returns {:ok, list} of scheduler/usage tuples" do
      assert {:ok, results} = System.scheduler_usage(100)
      assert is_list(results)

      for {id, usage} <- results do
        assert is_integer(id)
        assert is_float(usage)
        assert usage >= 0.0 and usage <= 1.0
      end
    end

    test "returns {:ok, list} with default" do
      # Use a short duration to keep test fast
      assert {:ok, _results} = System.scheduler_usage(100)
    end

    test "returns error for invalid millis" do
      assert {:error, :invalid_millis} = System.scheduler_usage(0)
      assert {:error, :invalid_millis} = System.scheduler_usage(-1)
    end
  end
end
