defmodule Inspector.TracingTest do
  use ExUnit.Case, async: true

  alias Inspector.Tracing

  describe "profile/2" do
    test "profiles a single pid and returns :ok" do
      pid = spawn(fn -> Process.sleep(1_000) end)

      assert {:ok, :done} = Tracing.profile(pid, 10)
    end

    test "profiles a list of pids" do
      pids = for _ <- 1..3, do: spawn(fn -> Process.sleep(1_000) end)

      assert {:ok, :done} = Tracing.profile(pids, 10)
    end

    test "accepts string pid format" do
      pid = spawn(fn -> Process.sleep(1_000) end)
      pid_str = inspect(pid)

      assert {:ok, :done} = Tracing.profile(pid_str, 10)
    end

    test "returns error for invalid pid input" do
      assert {:error, _} = Tracing.profile("not_a_pid", 10)
    end

    test "delegates from Inspector facade" do
      pid = spawn(fn -> Process.sleep(1_000) end)

      assert {:ok, :done} = Inspector.profile(pid, 10)
    end
  end
end
