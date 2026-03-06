defmodule Inspector.UtilsTest do
  use ExUnit.Case, async: true

  alias Inspector.Utils

  describe "to_pid/1" do
    test "passes through an actual pid" do
      pid = self()
      assert Utils.to_pid(pid) == pid
    end

    test "converts a 3-integer tuple" do
      pid = self()
      {a, b, c} = pid_components(pid)
      assert Utils.to_pid({a, b, c}) == pid
    end

    test "converts a #PID<a.b.c> string" do
      pid = self()
      str = inspect(pid)
      assert Utils.to_pid(str) == pid
    end

    test "converts a <a.b.c> string" do
      pid = self()
      {a, b, c} = pid_components(pid)
      assert Utils.to_pid("<#{a}.#{b}.#{c}>") == pid
    end

    test "converts a bare a.b.c string" do
      pid = self()
      {a, b, c} = pid_components(pid)
      assert Utils.to_pid("#{a}.#{b}.#{c}") == pid
    end

    test "resolves a registered atom name" do
      pid = self()
      Process.register(pid, :utils_test_registered)

      assert Utils.to_pid(:utils_test_registered) == pid
    after
      Process.unregister(:utils_test_registered)
    end

    test "raises ArgumentError for unregistered atom" do
      assert_raise ArgumentError, ~r/no process registered/, fn ->
        Utils.to_pid(:definitely_not_registered_xyz)
      end
    end

    test "raises ArgumentError for invalid string" do
      assert_raise ArgumentError, ~r/invalid PID string/, fn ->
        Utils.to_pid("not_a_pid")
      end
    end

    test "raises ArgumentError for partial dot string" do
      assert_raise ArgumentError, ~r/invalid PID string/, fn ->
        Utils.to_pid("0.1")
      end
    end

    test "raises ArgumentError for negative tuple components" do
      assert_raise ArgumentError, ~r/cannot convert/, fn ->
        Utils.to_pid({-1, 0, 0})
      end
    end

    test "raises ArgumentError for non-integer tuple components" do
      assert_raise ArgumentError, ~r/cannot convert/, fn ->
        Utils.to_pid({"a", "b", "c"})
      end
    end

    test "raises ArgumentError for unsupported types" do
      assert_raise ArgumentError, ~r/cannot convert/, fn ->
        Utils.to_pid(12345)
      end
    end
  end

  describe "safe_to_pid/1" do
    test "returns {:ok, pid} for valid input" do
      pid = self()
      assert {:ok, ^pid} = Utils.safe_to_pid(pid)
    end

    test "returns {:ok, pid} for tuple input" do
      pid = self()
      {a, b, c} = pid_components(pid)
      assert {:ok, ^pid} = Utils.safe_to_pid({a, b, c})
    end

    test "returns {:ok, pid} for string input" do
      pid = self()
      str = inspect(pid)
      assert {:ok, ^pid} = Utils.safe_to_pid(str)
    end

    test "returns {:error, reason} for invalid input" do
      assert {:error, msg} = Utils.safe_to_pid("garbage")
      assert is_binary(msg)
    end

    test "returns {:error, reason} for unregistered atom" do
      assert {:error, msg} = Utils.safe_to_pid(:no_such_process_xyz)
      assert msg =~ "no process registered"
    end

    test "returns {:error, reason} for unsupported type" do
      assert {:error, msg} = Utils.safe_to_pid([1, 2, 3])
      assert msg =~ "cannot convert"
    end
  end

  describe "to_port/1" do
    test "passes through an actual port" do
      port = hd(Port.list())
      assert Utils.to_port(port) == port
    end

    test "converts a #Port<0.X> string" do
      port = hd(Port.list())
      str = inspect(port)
      assert Utils.to_port(str) == port
    end

    test "converts a <0.X> angle-bracket string" do
      port = hd(Port.list())
      str = inspect(port) |> String.replace("#Port", "")
      assert Utils.to_port(str) == port
    end

    test "converts an integer index" do
      port = hd(Port.list())
      index = port_index(port)
      assert Utils.to_port(index) == port
    end

    test "raises ArgumentError for invalid string" do
      assert_raise ArgumentError, ~r/cannot convert/, fn ->
        Utils.to_port("not_a_port")
      end
    end

    test "raises ArgumentError for unsupported types" do
      assert_raise ArgumentError, ~r/cannot convert/, fn ->
        Utils.to_port({1, 2})
      end
    end
  end

  describe "safe_to_port/1" do
    test "returns {:ok, port} for valid input" do
      port = hd(Port.list())
      assert {:ok, ^port} = Utils.safe_to_port(port)
    end

    test "returns {:ok, port} for string input" do
      port = hd(Port.list())
      str = inspect(port)
      assert {:ok, ^port} = Utils.safe_to_port(str)
    end

    test "returns {:error, reason} for invalid input" do
      assert {:error, msg} = Utils.safe_to_port("garbage")
      assert is_binary(msg)
    end
  end

  defp port_index(port) do
    [_, index_str] = Regex.run(~r/#Port<0\.(\d+)>/, inspect(port))
    String.to_integer(index_str)
  end

  defp pid_components(pid) do
    [a, b, c] =
      pid
      |> inspect()
      |> String.trim_leading("#PID<")
      |> String.trim_trailing(">")
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)

    {a, b, c}
  end
end
