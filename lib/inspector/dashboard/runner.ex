defmodule Inspector.Dashboard.Runner do
  @moduledoc """
  Executes Inspector functions, optionally on remote nodes via RPC.
  """

  alias Inspector.Dashboard.FunctionDefs

  @spec execute(atom(), node(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def execute(function_key, node, raw_params) do
    case FunctionDefs.get(function_key) do
      nil ->
        {:error, "Unknown function: #{function_key}"}

      _func_def ->
        parsed = parse_params(function_key, raw_params)

        if node == node() do
          local_execute(function_key, parsed)
        else
          case :rpc.call(node, __MODULE__, :local_execute, [function_key, parsed]) do
            {:badrpc, reason} ->
              {:error, "RPC failed: #{inspect(reason)}"}

            result ->
              result
          end
        end
    end
  end

  @spec local_execute(atom(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def local_execute(function_key, parsed_params) do
    case FunctionDefs.get(function_key) do
      nil ->
        {:error, "Unknown function: #{function_key}"}

      _func_def ->
        try do
          result = FunctionDefs.execute(function_key, parsed_params)
          {:ok, format_result(result)}
        rescue
          e -> {:error, "Execution error: #{Exception.message(e)}"}
        catch
          kind, reason -> {:error, "Execution error: #{inspect({kind, reason})}"}
        end
    end
  end

  @spec format_result(term()) :: String.t()
  def format_result(term) do
    inspect(term, pretty: true, limit: :infinity, printable_limit: :infinity)
  end

  @spec parse_params(atom(), map()) :: map()
  def parse_params(function_key, raw_params) do
    case FunctionDefs.get(function_key) do
      nil -> %{}
      func_def -> do_parse(func_def.inputs, raw_params)
    end
  end

  defp do_parse(inputs, raw_params) do
    for input <- inputs, into: %{} do
      key = input.name
      raw = Map.get(raw_params, to_string(key), "")

      value =
        case {input.type, String.trim(raw)} do
          {_, ""} -> nil
          {:number, str} -> parse_integer(str)
          {:text, str} -> str
        end

      {key, value}
    end
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp parse_integer(str) do
    case Integer.parse(str) do
      {n, ""} -> n
      _ -> nil
    end
  end
end
