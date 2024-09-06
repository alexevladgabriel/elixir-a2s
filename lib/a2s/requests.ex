defmodule A2S.Requests do
  @queries [:info, :players, :rules]

  @type query() :: :info | :players | :rules

  @spec request(query) :: binary()
  def request(query) do
    case query do
      :info ->
        A2S.Requests.Info.request()

      :players ->
        A2S.Requests.Players.request()

      :rules ->
        A2S.Requests.Rules.request()

      term ->
        raise ArgumentError,
          message: "Unknown A2S Query: #{inspect(term)} (expected one of: #{inspect(@queries)})"
    end
  end

  def parse_response(header) do
    headers = [
      A2S.Requests.Info.get_info_source_header(),
      A2S.Requests.Info.get_info_goldsrc_header(),
      A2S.Requests.Players.get_player_response_header(),
      A2S.Requests.Rules.get_rules_response_header()
    ]

    case Enum.find_index(headers, fn x -> x === header end) do
      0 ->
        {:info, &A2S.Requests.Info.parse_source_response/1}

      1 ->
        {:info, &A2S.Requests.Info.parse_goldsrc_response/1}

      2 ->
        {:players, &A2S.Requests.Players.parse/1}

      3 ->
        {:rules, &A2S.Requests.Rules.parse/1}

      nil ->
        raise A2S.Error,
              "Unknown A2S Response Header: #{inspect(header)} (expected one of: #{inspect(headers)}"
    end
  end
end
