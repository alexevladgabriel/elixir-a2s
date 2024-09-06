defmodule A2S.Requests.Challenge do
  @simple_header <<-1::signed-32-little>>
  # 0x41 / 'A' - Challenge Request Header
  @challenge_request_header ?A

  def parse(<<@simple_header, @challenge_request_header, challenge::bytes>>) do
    {:challenge, challenge}
  end

  # reasonably clean wrapper around an ugly API
  def parse(<<@simple_header, _::bytes>> = packet) do
    case A2S.Packet.parse(packet) do
      {:error, error} -> {:error, error}
      response -> {:immediate, response}
    end
  end

  @spec parse!(binary()) ::
          {:challenge, binary()}
          | {:immediate, {:info, A2S.Requests.Info.t()}}
          | {:immediate, {:players, A2S.Requests.Players.t()}}
          | {:immediate, {:rules, A2S.Requests.Rules.t()}}
          | {:multipacket, {A2S.Packet.Multi.t(), binary()}}

  def parse!(packet) do
    case parse(packet) do
      {:error, error} -> raise error
      result -> result
    end
  end

  @spec sign(A2S.Requests.query(), binary()) :: binary()
  def sign(query, challenge) do
    packet = A2S.Requests.request(query)

    case query do
      :info ->
        <<packet <> challenge>>

      _ ->
        <<_type::32, header::8, _rest::bytes>> = packet
        A2S.Packet.create(:simple, header, challenge)
    end
  end

  def get_challenge_header, do: @challenge_request_header
end
