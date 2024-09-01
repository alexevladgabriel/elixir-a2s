defmodule A2S.Requests.Info do
  alias A2S.Requests.Info
  import A2S.Packet.Utils

  @type t() :: %__MODULE__{
          protocol: byte(),
          name: String.t(),
          map: String.t(),
          folder: String.t(),
          game: String.t(),
          appid: integer(),
          players: byte(),
          max_players: byte(),
          bots: byte(),
          server_type: :dedicated | :non_dedicated | :proxy | :unknown,
          environment: :linux | :windows | :mac | :unknown,
          visibility: :public | :private,
          vac: :secured | :unsecured | :unknown,
          # Extra Data Fields
          mod: :half_life | :half_life_mod | :unknown | nil,
          gameport: :inet.port_number() | nil,
          steamid: integer() | nil,
          spectator_port: :inet.port_number() | nil,
          spectator_name: String.t() | nil,
          keywords: String.t() | nil,
          gameid: integer() | nil
        }

  defstruct [
    :protocol,
    :name,
    :map,
    :folder,
    :game,
    :appid,
    :players,
    :max_players,
    :bots,
    :server_type,
    :environment,
    :visibility,
    :vac,
    :version,
    # Extra Data Fields (Not guaranteed)
    :mod,
    :gameport,
    :steamid,
    :spectator_port,
    :spectator_name,
    :keywords,
    :gameid
  ]

  # 0x54 / 'T' - Info Request Header
  @info_request_header ?T
  # 0x49 / 'I' - Info Source Request Header
  @info_response_header ?I
  # 0x6D / 'm' - Info GoldSrc Request Header
  @info_goldsrc_response_header ?m

  @info_request_payload "Source Engine Query\0"

  @spec request() :: binary()
  def request() do
    A2S.Packet.create(:simple, @info_request_header, @info_request_payload)
  end

  def parse_source_response(response) when is_binary(response) do
    <<protocol::8, data::bytes>> = response

    {name, data} = read_null_term_string(data)
    {map, data} = read_null_term_string(data)
    {folder, data} = read_null_term_string(data)
    {game, data} = read_null_term_string(data)

    <<
      id::16,
      players::8,
      max_players::8,
      bots::8,
      server_type::8,
      environment::8,
      visibility::8,
      vac::8,
      data::bytes
    >> = data

    {version, data} = read_null_term_string(data)

    {gameport, steamid, spectator_port, spectator_name, keywords, gameid} = parse_edf(data)

    %Info{
      protocol: protocol,
      name: name,
      map: map,
      folder: folder,
      game: game,
      players: players,
      max_players: max_players,
      bots: bots,
      server_type: parse_server_type(server_type),
      environment: parse_environment(environment),
      visibility: parse_visibility(visibility),
      vac: parse_vac(vac),
      version: version,
      gameport: gameport,
      steamid: steamid,
      spectator_port: spectator_port,
      spectator_name: spectator_name,
      keywords: keywords,
      gameid: gameid,
      appid: parse_app_id(gameid, id)
    }
  end

  def parse_goldsrc_response(response) when is_binary(response) do
    {_address, data} = read_null_term_string(response)
    {name, data} = read_null_term_string(data)
    {map, data} = read_null_term_string(data)
    {folder, data} = read_null_term_string(data)
    {game, data} = read_null_term_string(data)

    <<
      players::8,
      max_players::8,
      protocol::8,
      server_type::8,
      environment::8,
      visibility::8,
      mod::8,
      vac::8,
      bots::8
    >> = data

    %Info{
      protocol: protocol,
      name: name,
      map: map,
      folder: folder,
      game: game,
      players: players,
      max_players: max_players,
      bots: bots,
      server_type: parse_server_type(server_type),
      environment: parse_environment(environment),
      visibility: parse_visibility(visibility),
      vac: parse_vac(vac),
      version: nil,
      gameport: nil,
      steamid: nil,
      spectator_port: nil,
      spectator_name: nil,
      keywords: nil,
      gameid: nil,
      # GoldSrc does not provide AppID
      mod: parse_mod(mod),
      appid: 0
    }
  end

  defp parse_app_id(gameid, id) do
    import Bitwise, only: [&&&: 2]

    case gameid do
      nil -> id
      _ -> gameid &&& 0xFFFFFF
    end
  end

  defp parse_server_type(t) do
    case t do
      ?d -> :dedicated
      ?l -> :non_dedicated
      ?p -> :proxy
      _ -> :unknown
    end
  end

  def parse_mod(mod) do
    case mod do
      0 -> :half_life
      1 -> :half_life_mod
      _ -> :unknown
    end
  end

  defp parse_environment(e) do
    case e do
      ?l -> :linux
      ?w -> :windows
      ?m -> :mac
      ?o -> :mac
      _ -> :unknown
    end
  end

  defp parse_visibility(v) do
    case v do
      0 -> :public
      1 -> :private
      _ -> :unknown
    end
  end

  defp parse_vac(0), do: :unsecured
  defp parse_vac(1), do: :secured
  defp parse_vac(_), do: :unknown

  # Helper functions
  def get_info_request_header(), do: @info_request_header
  def get_info_request_payload(), do: @info_request_payload
  def get_info_source_header(), do: @info_response_header
  def get_info_goldsrc_header(), do: @info_goldsrc_response_header
end
