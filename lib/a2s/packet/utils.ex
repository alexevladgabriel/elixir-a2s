defmodule A2S.Packet.Utils do
  # Mutlipacket utils
  def glue_packets(packets, acc \\ [])
  def glue_packets([], acc), do: IO.iodata_to_binary(acc)

  def glue_packets([{_multipacket_header, payload} | tail], acc) do
    glue_packets(tail, [acc | payload])
  end

  def sort_multipacket(collected),
    do: Enum.sort(collected, fn {%{index: a}, _}, {%{index: b}, _} -> a < b end)

  # EDF parsing utils
  def parse_edf(<<>>), do: %{}

  def parse_edf(<<edf::8, data::bytes>>) do
    import Bitwise, only: [&&&: 2]

    {gameport, data} =
      if (edf &&& 0x80) !== 0 do
        <<gameport::16-little, data::bytes>> = data
        {gameport, data}
      else
        {nil, data}
      end

    {steamid, data} =
      if (edf &&& 0x10) !== 0 do
        <<steamid::signed-64-little, data::bytes>> = data
        {steamid, data}
      else
        {nil, data}
      end

    {spec_port, spec_name, data} =
      if (edf &&& 0x40) !== 0 do
        <<port::signed-16-little, data::bytes>> = data
        {name, data} = read_null_term_string(data)
        {port, name, data}
      else
        {nil, nil, data}
      end

    {keywords, data} =
      if (edf &&& 0x20) !== 0 do
        read_null_term_string(data)
      else
        {nil, data}
      end

    gameid =
      if (edf &&& 0x01) !== 0 do
        <<gameid::signed-64-little>> = data
        gameid
      else
        nil
      end

    {gameport, steamid, spec_port, spec_name, keywords, gameid}
  end

  def read_null_term_string(data, str \\ [])

  def read_null_term_string(<<0, rest::bytes>>, str) do
    {str |> IO.iodata_to_binary() |> String.replace_invalid(), rest}
  end

  def read_null_term_string(<<char::8, rest::bytes>>, str) do
    read_null_term_string(rest, [str, char])
  end
end
