defmodule Inspector.Utils do
  @moduledoc """
  Utilities for converting various PID and port representations to actual
  `pid()` and `port()` values.

  All Inspector functions that accept a PID or port argument pipe through
  these converters, so you can pass them in whichever format is most convenient.

  ## Accepted PID formats

    * `pid()` — passed through as-is
    * `{a, b, c}` — three-integer tuple, e.g. `{0, 570, 0}`
    * `"#PID<0.570.0>"` — full IEx-style string
    * `"<0.570.0>"` — angle-bracket string
    * `"0.570.0"` — bare dot-separated string (common in log output)
    * `atom` — registered name resolved via `Process.whereis/1`

  ## Accepted port formats

    * `port()` — passed through as-is
    * `integer` — port index, e.g. `2013`
    * `"#Port<0.2013>"` — full IEx-style string
    * `"<0.2013>"` — angle-bracket string
    * `atom` — registered name
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

  # -- Port conversion --

  @typedoc "Any value that can be converted to a port."
  @type port_input :: port() | non_neg_integer() | String.t() | atom()

  @doc """
  Converts a port representation to an actual `port()`.

  Raises `ArgumentError` if the input cannot be converted.

  ## Examples

      iex> port = hd(Port.list())
      iex> Inspector.Utils.to_port(port) == port
      true

  """
  @spec to_port(port_input()) :: port()
  def to_port(port) when is_port(port), do: port

  def to_port(index) when is_integer(index) and index >= 0 do
    parse_port_string("#Port<0.#{index}>")
  end

  def to_port("#Port" <> _ = str) when is_binary(str) do
    parse_port_string(str)
  end

  def to_port("<" <> _ = str) when is_binary(str) do
    parse_port_string("#Port" <> str)
  end

  def to_port(name) when is_atom(name) do
    case Port.info(name) do
      nil -> raise ArgumentError, "no port registered as #{inspect(name)}"
      _info -> :erlang.whereis(name)
    end
  end

  def to_port(other) do
    raise ArgumentError, "cannot convert #{inspect(other)} to port"
  end

  @doc """
  Converts a port representation to an actual `port()`, returning an ok/error tuple.

  ## Examples

      iex> port = hd(Port.list())
      iex> {:ok, ^port} = Inspector.Utils.safe_to_port(port)

      iex> Inspector.Utils.safe_to_port("not_a_port")
      {:error, "cannot convert \\"not_a_port\\" to port"}

  """
  @spec safe_to_port(port_input()) :: {:ok, port()} | {:error, String.t()}
  def safe_to_port(input) do
    {:ok, to_port(input)}
  rescue
    ArgumentError -> {:error, format_port_error(input)}
  end

  defp parse_port_string(str) do
    str
    |> String.to_charlist()
    |> :erlang.list_to_port()
  rescue
    ArgumentError -> raise ArgumentError, "invalid port string: #{inspect(str)}"
  end

  defp format_port_error(name) when is_atom(name),
    do: "no port registered as #{inspect(name)}"

  defp format_port_error(input),
    do: "cannot convert #{inspect(input)} to port"
end
