defmodule A2S.Requests.Players do
  alias A2S.Requests.Players
  import A2S.Packet.Utils

  @type t() :: %__MODULE__{
          count: byte(),
          players: list(A2S.Requests.Players.Player.t())
        }

  defstruct [
    :count,
    :players
  ]

  defmodule Player do
    @type t() :: %__MODULE__{
            index: integer(),
            name: String.t(),
            score: integer(),
            duration: float()
          }

    defstruct [
      :index,
      :name,
      :score,
      :duration
    ]
  end

  # 0x55 / 'U' - Player Request Header
  @player_request_header ?U
  # 0x44 / 'D' - Player Response Header
  @player_response_header ?D

  def request() do
    A2S.Packet.create(:simple, @player_request_header, <<-1::signed-32-little>>)
  end

  def parse(packet) do
    <<count::8, rest::binary>> = packet

    %Players{
      count: count,
      players: parse_players(rest)
    }
  end

  @spec parse_players(binary()) :: list(Player.t())
  defp parse_players(data, players \\ [])
  defp parse_players(<<>>, players), do: Enum.reverse(players)

  defp parse_players(data, players) do
    <<index::8, data::bytes>> = data
    {name, data} = read_null_term_string(data)
    <<score::signed-32-little, data::bytes>> = data
    <<duration::float-32-little, data::bytes>> = data

    player = %Player{
      index: index,
      name: name,
      score: score,
      duration: duration
    }

    parse_players(data, [player | players])
  end

  # Helper functions
  def get_player_request_header(), do: @player_request_header
  def get_player_response_header(), do: @player_response_header
end
