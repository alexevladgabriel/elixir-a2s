defmodule A2S.Statem do
  @moduledoc false
  alias A2S.Packet

  # A state machine process responsible for handling all A2S queries to a game server running at the given address.
  # Queries must be performed sequentially per address as A2S provides no way to associate what replies associate to what responses.
  # Each instance should exit normally after a certain interval of inactivity (currently hard-coded to 2 minutes).

  @behaviour :gen_statem

  require Logger

  @impl :gen_statem
  def callback_mode(), do: :handle_event_function

  defmodule SocketState do
    @moduledoc false
    defstruct [:address, :caller, :query, :total, :parts, :socket]
  end

  @type init_args() :: {{:inet.ip_address(), :inet.port_number()}, term()}

  @spec child_spec(init_args) :: Supervisor.child_spec()
  def child_spec({address, client}) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [{address, client}]},
      restart: :transient
    }
  end

  @spec start_link(init_args) :: :ignore | {:ok, pid()} | {:error, term()}
  def start_link({address, client}) do
    registry = A2S.Client.registry_name(client)
    socket = A2S.Client.socket_name(client)

    :gen_statem.start_link(via_registry(registry, address), __MODULE__, {address, socket}, [])
  end

  @impl :gen_statem
  def init({address, socket}) do
    {:ok, :idle, %SocketState{address: address, socket: socket}, idle_timeout()}
  end

  ## State Machine Callbacks

  # Received a query to perform

  @impl :gen_statem
  def handle_event({:call, from}, query, :idle, data) do
    %SocketState{address: address, socket: socket} = data

    :ok = GenServer.call(socket, {address, A2S.Requests.request(query)})

    {
      :next_state,
      :await_challenge,
      %SocketState{data | caller: from, query: query},
      recv_timeout()
    }
  end

  @impl :gen_statem
  def handle_event({:call, _from}, _query_type, _state, _data) do
    {:keep_state_and_data, :postpone}
  end

  # Received a reply to a query
  @impl :gen_statem
  def handle_event(:cast, packet, :await_challenge, data) do
    %SocketState{
      address: address,
      query: query,
      socket: socket
    } = data

    case A2S.Requests.Challenge.parse(packet) do
      {:immediate, msg} ->
        reply_and_next(msg, data)

      {:challenge, challenge} ->
        :ok =
          GenServer.call(
            socket,
            {address, A2S.Requests.Challenge.sign(query, challenge)}
          )

        {:next_state, :await_response, data, recv_timeout()}

      {:error, reason} ->
        reply_and_next({:error, reason}, data)
    end
  end

  @impl :gen_statem
  def handle_event(:cast, packet, :await_response, data) do
    case Packet.parse(packet) do
      # {:multipacket, {header, _body} = part} ->
      #   {
      #     :next_state,
      #     :collect_multipacket,
      #     %SocketState{data | total: header.total, parts: [part]},
      #     recv_timeout()
      #   }

      # reply with whatever the result is.
      msg ->
        reply_and_next(msg, data)
    end
  end

  # Received a timeout
  @impl :gen_statem
  def handle_event(:state_timeout, :idle_timeout, :idle, _data) do
    dbg("Received an idle timeout")
    {:stop, :normal}
  end

  @impl :gen_statem
  def handle_event(:state_timeout, :recv_timeout, _state, data) do
    dbg("Received a timeout")
    reply_and_next({:error, :recv_timeout}, data)
  end

  defp reply_and_next(msg, %SocketState{address: address, caller: caller, socket: socket}) do
    dbg("Forwarding message")
    :gen_statem.reply(caller, msg)

    {
      :next_state,
      :idle,
      %SocketState{address: address, socket: socket}
    }
  end

  ## Timeout Definitions
  defp idle_timeout() do
    timeout = :persistent_term.get({__MODULE__, :idle_timeout})
    {:state_timeout, timeout, :idle_timeout}
  end

  defp recv_timeout() do
    timeout = :persistent_term.get({__MODULE__, :recv_timeout})
    {:state_timeout, timeout, :recv_timeout}
  end

  # Helper functions
  defp via_registry(registry, address),
    do: {:via, Registry, {registry, address}}
end
