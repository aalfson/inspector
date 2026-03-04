defmodule Inspector.Dashboard.FunctionDefsTest do
  use ExUnit.Case, async: true

  alias Inspector.Dashboard.FunctionDefs

  describe "all/0" do
    test "returns non-empty list" do
      assert length(FunctionDefs.all()) > 0
    end

    test "every def has required fields" do
      for func <- FunctionDefs.all() do
        assert is_atom(func.key), "key missing for #{inspect(func)}"
        assert is_binary(func.label), "label missing for #{func.key}"
        assert func.group in [:process, :top, :aggregate], "invalid group for #{func.key}"
        assert is_binary(func.description), "description missing for #{func.key}"
        assert is_list(func.inputs), "inputs missing for #{func.key}"
      end
    end

    test "every input has required fields" do
      for func <- FunctionDefs.all(), input <- func.inputs do
        assert is_atom(input.name), "input name missing in #{func.key}"
        assert is_binary(input.label), "input label missing in #{func.key}"
        assert input.type in [:text, :number], "invalid input type in #{func.key}"
      end
    end
  end

  describe "get/1" do
    test "returns def for valid key" do
      func = FunctionDefs.get(:top_memory)
      assert func.key == :top_memory
      assert func.group == :top
    end

    test "returns nil for unknown key" do
      assert FunctionDefs.get(:nonexistent) == nil
    end
  end

  describe "find_by_key_string/1" do
    test "finds def by string key" do
      func = FunctionDefs.find_by_key_string("top_memory")
      assert func.key == :top_memory
    end

    test "returns nil for unknown string" do
      assert FunctionDefs.find_by_key_string("nonexistent") == nil
    end
  end

  describe "grouped/0" do
    test "returns 3 groups in order" do
      groups = FunctionDefs.grouped()
      keys = Enum.map(groups, &elem(&1, 0))
      assert keys == [:top, :aggregate, :process]
    end

    test "each group has at least one function" do
      for {_group, fns} <- FunctionDefs.grouped() do
        assert length(fns) > 0
      end
    end
  end
end
