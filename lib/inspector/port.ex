defmodule Inspector.Port do
  @moduledoc """
  Detailed port inspection.

  Wraps `:recon.port_info/1` with flexible port input conversion.
  Accepts ports in multiple formats — see `Inspector.Utils.to_port/1`.
  """

  @doc """
  Returns detailed info about a port as a keyword list of categories.

  Each category contains key-value pairs describing that aspect of the port
  (e.g., signals, io, memory, type-specific details for inet ports).

  ## Accepted port formats

    * `port()` — passed through
    * `integer` — port index, e.g. `2013`
    * `"#Port<0.2013>"` — full string
    * `"<0.2013>"` — angle-bracket string
    * `atom` — registered name

  ## Examples

      iex> Inspector.Port.info("#Port<0.6>")
      {:ok, [{:meta, [...]}, {:signals, [...]}, ...]}

  """
  @spec info(Inspector.Utils.port_input()) :: {:ok, term()} | {:error, term()}
  def info(port_input) do
    port = Inspector.Utils.to_port(port_input)
    result = :recon.port_info(port)
    {:ok, result}
  rescue
    e -> {:error, Exception.message(e)}
  end
end
