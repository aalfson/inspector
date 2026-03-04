defmodule Inspector.Dashboard.Runner do
  @moduledoc """
  Executes Inspector functions, optionally on remote nodes via RPC.
  """

  alias Inspector.Dashboard.FunctionDefs

  @spec execute(atom(), node(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def execute(function_key, target_node, raw_params) do
    with :ok <- validate_function(function_key),
         :ok <- validate_node(target_node) do
      parsed = parse_params(function_key, raw_params)
      run(function_key, target_node, parsed)
    end
  end

  @spec local_execute(atom(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def local_execute(function_key, parsed_params) do
    with :ok <- validate_function(function_key) do
      safe_execute(function_key, parsed_params)
    end
  end

  defp validate_function(key) do
    if FunctionDefs.get(key), do: :ok, else: {:error, "Unknown function: #{key}"}
  end

  defp validate_node(target_node) do
    if target_node in [node() | Node.list()],
      do: :ok,
      else: {:error, "Node not connected: #{target_node}"}
  end

  defp run(function_key, target_node, parsed) when target_node == node() do
    local_execute(function_key, parsed)
  end

  defp run(function_key, target_node, parsed) do
    case :rpc.call(target_node, __MODULE__, :local_execute, [function_key, parsed]) do
      {:badrpc, reason} -> {:error, "RPC failed: #{inspect(reason)}"}
      result -> result
    end
  end

  defp safe_execute(function_key, parsed_params) do
    function_key
    |> FunctionDefs.execute(parsed_params)
    |> normalize_result()
  rescue
    e -> {:error, "Execution error: #{Exception.message(e)}"}
  catch
    kind, reason -> {:error, "Execution error: #{inspect({kind, reason})}"}
  end

  defp normalize_result({:error, reason}), do: {:error, format_error(reason)}
  defp normalize_result({:ok, result}), do: {:ok, format_result(result)}
  defp normalize_result(result), do: {:ok, format_result(result)}

  @spec format_result(term()) :: String.t()
  def format_result(term) do
    inspect(term, pretty: true, limit: :infinity, printable_limit: :infinity)
  end

  defp format_error(:not_found), do: "Process not found"

  defp format_error(:mailbox_too_large),
    do: "Mailbox too large (>1000 messages). Use force option."

  defp format_error({:unknown_system_msg, _}),
    do: "Process does not support state inspection (not an OTP process)"

  defp format_error(reason), do: inspect(reason, pretty: true)

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
