defmodule A2S.Socket do
  @moduledoc false
  # GenServer wrapper over `:gen_udp` responsible for sending packets to game servers
  # and routing received packets to the appropriate `A2S.Statem` process.

  use GenServer

  defmodule SocketState do
    @moduledoc false
    defstruct [:socket, :registry]
  end

  @spec start_link(keyword()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(opts) do
    name = name!(opts)
    port = port!(opts)
    registry = registry!(opts)

    GenServer.start_link(__MODULE__, {port, registry}, name: name)
  end

  ## Initialization
  @impl true
  def init({port, registry}) do
    case :gen_udp.open(port, [:binary, active: true]) do
      {:ok, socket} ->
        {:ok, %SocketState{socket: socket, registry: registry}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  ## GenServer Callbacks

  # Forward received UDP packets to the appropriate `A2S.Statem` process
  @impl true
  def handle_info({:udp, _socket, ip, port, packet}, %SocketState{} = state) do
    GenServer.cast(via_registry(state.registry, {ip, port}), packet)
    {:noreply, state}
  end

  # Send UDP packets back to the game server
  @impl true
  def handle_call({dst_address, packet}, _from, %SocketState{} = state) do
    {:reply, :gen_udp.send(state.socket, dst_address, packet), state}
  end

  ## Helper functions
  defp via_registry(registry, name),
    do: {:via, Registry, {registry, name}}

  defp name!(opts),
    do: Keyword.get(opts, :name) || raise(ArgumentError, "must provide a name")

  defp port!(opts),
    do: Keyword.get(opts, :port) || raise(ArgumentError, "must provide a port for the UDP socket")

  defp registry!(opts),
    do: Keyword.get(opts, :a2s_registry) || raise(ArgumentError, "must provide a registry")
end
