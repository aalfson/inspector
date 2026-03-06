defmodule Inspector.Network do
  @moduledoc """
  Top N network ports by packet/byte metrics.

  Wraps `:recon.inet_count/2` for absolute snapshots and `:recon.inet_window/3`
  for delta-based measurement over a time window.

  ## Supported attributes

    * `:recv_cnt` — received packet count
    * `:recv_oct` — received bytes (octets)
    * `:send_cnt` — sent packet count
    * `:send_oct` — sent bytes (octets)
    * `:cnt` — total packet count (recv + send)
    * `:oct` — total bytes (recv + send)
  """

  @valid_attributes ~w(recv_cnt recv_oct send_cnt send_oct cnt oct)a

  @typedoc "A network port entry with its metric value and port reference."
  @type result :: %{
          port: port(),
          value: non_neg_integer(),
          metadata: [{atom(), term()}]
        }

  @doc """
  Returns the top `n` network ports by the given attribute (absolute snapshot).

  Wraps `:recon.inet_count/2`.

  ## Defaults

    * `attribute` — `:cnt`
    * `n` — `10`

  ## Examples

      iex> Inspector.Network.inet_count()
      {:ok, [%{port: #Port<0.6>, value: 120, metadata: [...]}]}

  """
  @spec inet_count(atom(), pos_integer()) :: {:ok, [result()]} | {:error, term()}
  def inet_count(attribute \\ :cnt, n \\ 10) do
    with :ok <- validate_attribute(attribute),
         :ok <- validate_count(n) do
      results = :recon.inet_count(attribute, n)
      {:ok, Enum.map(results, &format_result/1)}
    end
  end

  @doc """
  Returns the top `n` network ports by the given attribute over a time window.

  Wraps `:recon.inet_window/3`.

  ## Defaults

    * `attribute` — `:cnt`
    * `n` — `10`
    * `millis` — `1000`

  ## Examples

      iex> Inspector.Network.inet_window(:oct, 5, 2000)
      {:ok, [%{port: #Port<0.6>, value: 4096, metadata: [...]}]}

  """
  @spec inet_window(atom(), pos_integer(), pos_integer()) :: {:ok, [result()]} | {:error, term()}
  def inet_window(attribute \\ :cnt, n \\ 10, millis \\ 1000) do
    with :ok <- validate_attribute(attribute),
         :ok <- validate_count(n),
         :ok <- validate_millis(millis) do
      results = :recon.inet_window(attribute, n, millis)
      {:ok, Enum.map(results, &format_result/1)}
    end
  end

  defp validate_attribute(attr) when attr in @valid_attributes, do: :ok
  defp validate_attribute(attr), do: {:error, {:invalid_attribute, attr}}

  defp validate_count(n) when is_integer(n) and n > 0, do: :ok
  defp validate_count(_), do: {:error, :invalid_count}

  defp validate_millis(ms) when is_integer(ms) and ms > 0, do: :ok
  defp validate_millis(_), do: {:error, :invalid_millis}

  defp format_result({port, value, metadata}) do
    %{
      port: port,
      value: value,
      metadata: metadata
    }
  end
end
