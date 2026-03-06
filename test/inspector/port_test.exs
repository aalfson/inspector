defmodule Inspector.PortTest do
  use ExUnit.Case, async: true

  describe "info/1" do
    test "returns {:ok, result} for a valid port" do
      port = hd(:erlang.ports())
      assert {:ok, result} = Inspector.Port.info(port)
      assert is_list(result)
    end

    test "accepts port string format" do
      port = hd(:erlang.ports())
      port_str = inspect(port)
      assert {:ok, _result} = Inspector.Port.info(port_str)
    end

    test "accepts angle-bracket string format" do
      port = hd(:erlang.ports())
      port_str = inspect(port) |> String.replace("#Port", "")
      assert {:ok, _result} = Inspector.Port.info(port_str)
    end

    test "accepts integer index" do
      port = hd(:erlang.ports())
      [_, index_str] = Regex.run(~r/#Port<0\.(\d+)>/, inspect(port))
      index = String.to_integer(index_str)
      assert {:ok, _result} = Inspector.Port.info(index)
    end

    test "returns error for invalid port input" do
      assert {:error, _reason} = Inspector.Port.info("not_a_port")
    end
  end
end
