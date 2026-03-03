defmodule Inspector.Utils do
  @moduledoc """
  Utilities for converting various PID representations to actual `pid()` values.

  All Inspector functions that accept a PID argument pipe through these converters,
  so you can pass PIDs in whichever format is most convenient.

  ## Accepted formats

    * `pid()` — passed through as-is
    * `{a, b, c}` — three-integer tuple, e.g. `{0, 570, 0}`
    * `"#PID<0.570.0>"` — full IEx-style string
    * `"<0.570.0>"` — angle-bracket string
    * `"0.570.0"` — bare dot-separated string (common in log output)
    * `atom` — registered name resolved via `Process.whereis/1`
  """

  @typedoc "Any value that can be converted to a pid."
  @type pid_input ::
          pid()
          | {non_neg_integer(), non_neg_integer(), non_neg_integer()}
          | String.t()
          | atom()

  @doc """
  Converts a PID representation to an actual `pid()`.

  Raises `ArgumentError` if the input cannot be converted.

  ## Examples

      iex> Inspector.Utils.to_pid(self())
      self()

      iex> pid = self()
      iex> {a, b, c} = {0, 0, 0}
      iex> Inspector.Utils.to_pid({a, b, c})
      :c.pid(a, b, c)

  """
  @spec to_pid(pid_input()) :: pid()
  def to_pid(pid) when is_pid(pid), do: pid

  def to_pid({a, b, c})
      when is_integer(a) and is_integer(b) and is_integer(c) and
             a >= 0 and b >= 0 and c >= 0 do
    :c.pid(a, b, c)
  end

  def to_pid("#PID" <> rest) when is_binary(rest) do
    parse_angle_bracket_pid(rest)
  end

  def to_pid("<" <> _ = str) when is_binary(str) do
    parse_angle_bracket_pid(str)
  end

  def to_pid(str) when is_binary(str) do
    if Regex.match?(~r/^\d+\.\d+\.\d+$/, str) do
      parse_angle_bracket_pid("<#{str}>")
    else
      raise ArgumentError, "invalid PID string: #{inspect(str)}"
    end
  end

  def to_pid(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> raise ArgumentError, "no process registered as #{inspect(name)}"
      pid -> pid
    end
  end

  def to_pid(other) do
    raise ArgumentError, "cannot convert #{inspect(other)} to pid"
  end

  @doc """
  Converts a PID representation to an actual `pid()`, returning an ok/error tuple.

  ## Examples

      iex> {:ok, pid} = Inspector.Utils.safe_to_pid(self())
      iex> pid == self()
      true

      iex> Inspector.Utils.safe_to_pid("not_a_pid")
      {:error, "invalid PID string: \\"not_a_pid\\""}

  """
  @spec safe_to_pid(pid_input()) :: {:ok, pid()} | {:error, String.t()}
  def safe_to_pid(input) do
    {:ok, to_pid(input)}
  rescue
    ArgumentError -> {:error, format_error(input)}
  end

  defp parse_angle_bracket_pid(str) do
    str
    |> String.to_charlist()
    |> :erlang.list_to_pid()
  rescue
    ArgumentError -> raise ArgumentError, "invalid PID string: #{inspect(str)}"
  end

  defp format_error(name) when is_atom(name), do: "no process registered as #{inspect(name)}"
  defp format_error(input), do: "cannot convert #{inspect(input)} to pid"
end
