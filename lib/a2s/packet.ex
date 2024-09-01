defmodule A2S.Packet do
  @simple_header <<-1::signed-32-little>>
  @multipacket_header <<-2::signed-32-little>>

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
