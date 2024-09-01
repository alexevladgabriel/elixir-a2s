defmodule A2S.Client do
  @moduledoc false

  use Supervisor

  @default_name A2S_Singleton

  defmodule Config do
    @moduledoc false
    defstruct [:name, :port, :idle_timeout, :recv_timeout]
  end

  # Initialize the singleton supervisor
  def child_spec(opts) do
    %{
      id: a2s_name(opts),
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @spec start_link(keyword()) :: :ignore | {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    name = a2s_name(opts)

    config = %Config{
      name: name,
      port: Keyword.get(opts, :port, 20850),
      idle_timeout: Keyword.get(opts, :idle_timeout, 120_000),
      recv_timeout: Keyword.get(opts, :recv_timeout, 3_000)
    }

    Supervisor.start_link(__MODULE__, config, name: supervisor_name(name))
  end

  @impl true
  def init(%Config{} = config) do
    %Config{
      name: name,
      port: port,
      idle_timeout: idle_timeout,
      recv_timeout: recv_timeout
    } = config

    :persistent_term.put({A2S.Statem, :recv_timeout}, recv_timeout)
    :persistent_term.put({A2S.Statem, :idle_timeout}, idle_timeout)

    children = [
      {Registry, [keys: :unique, name: registry_name(name)]},
      {A2S.DynamicSupervisor, [name: dynamic_supervisor_name(name)]},
      {A2S.Socket, [name: socket_name(name), port: port, a2s_registry: registry_name(name)]}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  ## API

  @doc """
  Query a game server running at `address` for the data specified by `query`.

  Additional options are available as a keyword list:
  * `:name` - Alias of the top-level supervisor. Defaults to `A2S.Client`.

  * `:timeout` - Absolute timeout for the request to complete. Defaults to `5000` or 5 seconds.
  """
  @spec query(
          :info | :players | :rules,
          {:inet.ip_address(), :inet.port_number()},
          list({atom(), any()})
        ) ::
          {:info, A2S.Requests.Info.t()}
          | {:players, A2S.Requests.Players.t()}
          | {:rules, A2S.Requests.Rules.t()}
          | {:error, any}

  def query(query, address, opts \\ []) do
    client_name = Keyword.get(opts, :name, @default_name)
    timeout = Keyword.get(opts, :timeout, 5000)

    :gen_statem.call(find_or_start(address, client_name), query, timeout)
  end

  defp find_or_start(address, client) do
    registry = registry_name(client)

    case Registry.lookup(registry, address) do
      [{pid, _value}] ->
        pid

      [] ->
        case A2S.DynamicSupervisor.start_child(address, client) do
          {:ok, pid} -> pid
          {:ok, pid, _info} -> pid
          {:error, {:already_started, pid}} -> pid
        end
    end
  end

  # Helper functions

  defp a2s_name(opts), do: Keyword.get(opts, :name, @default_name)

  @doc false
  def registry_name(name), do: :"#{name}.Registry"

  @doc false
  def dynamic_supervisor_name(name), do: :"#{name}.DynamicSupervisor"

  @doc false
  def socket_name(name), do: :"#{name}.Socket"

  @doc false
  def supervisor_name(name), do: :"#{name}.Supervisor"
end
