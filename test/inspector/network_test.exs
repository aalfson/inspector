defmodule Inspector.NetworkTest do
  use ExUnit.Case, async: true

  alias Inspector.Network

  describe "inet_count/2" do
    test "returns {:ok, list} with defaults" do
      assert {:ok, results} = Network.inet_count()
      assert is_list(results)
    end

    test "returns results with expected shape" do
      assert {:ok, results} = Network.inet_count(:cnt, 5)

      for entry <- results do
        assert is_port(entry.port)
        assert is_integer(entry.value)
        assert is_list(entry.metadata)
      end
    end

    test "n parameter limits result count" do
      assert {:ok, results} = Network.inet_count(:cnt, 3)
      assert length(results) <= 3
    end

    test "accepts all valid attributes" do
      for attr <- ~w(recv_cnt recv_oct send_cnt send_oct cnt oct)a do
        assert {:ok, _} = Network.inet_count(attr, 3)
      end
    end

    test "returns error for invalid attribute" do
      assert {:error, {:invalid_attribute, :garbage}} = Network.inet_count(:garbage, 5)
    end

    test "returns error for invalid count" do
      assert {:error, :invalid_count} = Network.inet_count(:cnt, 0)
      assert {:error, :invalid_count} = Network.inet_count(:cnt, -1)
    end
  end

  describe "inet_window/3" do
    test "returns {:ok, list} with defaults" do
      assert {:ok, results} = Network.inet_window()
      assert is_list(results)
    end

    test "returns results with expected shape" do
      assert {:ok, results} = Network.inet_window(:cnt, 5, 100)

      for entry <- results do
        assert is_port(entry.port)
        assert is_integer(entry.value)
        assert is_list(entry.metadata)
      end
    end

    test "accepts all valid attributes" do
      for attr <- ~w(recv_cnt recv_oct send_cnt send_oct cnt oct)a do
        assert {:ok, _} = Network.inet_window(attr, 3, 100)
      end
    end

    test "returns error for invalid attribute" do
      assert {:error, {:invalid_attribute, :garbage}} = Network.inet_window(:garbage, 5, 100)
    end

    test "returns error for invalid count" do
      assert {:error, :invalid_count} = Network.inet_window(:cnt, 0, 100)
    end

    test "returns error for invalid millis" do
      assert {:error, :invalid_millis} = Network.inet_window(:cnt, 5, 0)
      assert {:error, :invalid_millis} = Network.inet_window(:cnt, 5, -1)
    end
  end
end
