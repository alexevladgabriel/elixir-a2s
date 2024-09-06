defmodule A2S.Packet do
  import A2S.Packet.Utils
  @simple_header <<-1::signed-32-little>>
  @multipacket_header <<-2::signed-32-little>>

  defmodule MultiPacket do
    @moduledoc """
    Struct representing a [multi-packet response header](https://developer.valvesoftware.com/wiki/Server_queries#Multi-packet_Response_Format).
    """
    defstruct [
      :id,
      :total,
      :index,
      :size
    ]

    @type t() :: %MultiPacket{
            id: integer(),
            total: byte(),
            index: byte(),
            size: integer()
          }
  end

  @type type() :: :simple | :multipacket

  def create(type, header, payload) when type === :simple do
    <<@simple_header, header::8, payload::bytes>>
  end

  def create(type, header, payload) when type === :multipacket do
    <<@multipacket_header, header::8, payload::bytes>>
  end

  def parse(<<@simple_header, header::8, payload::bytes>> = _packet) do
    dbg("Parsing Simple Packet")
    {query_type, parse_fn} = A2S.Requests.parse_response(header)

    try do
      {query_type, parse_fn.(payload)}
    rescue
      error ->
        {:error,
         %A2S.Error{
           message:
             "Failed to parse response of #{query_type} (#{inspect(payload)}): #{inspect(error)}"
         }}
    end
  end
end
