defmodule A2S.Requests.Rules do
  @type t() :: %__MODULE__{
          count: byte(),
          rules: list({String.t(), String.t()})
        }
  defstruct [
    :count,
    :rules
  ]

  # 0x56 / 'V' - Rules Request Header
  @rules_challenge_header ?V
  # 0x45 / 'E' - Rules Response Header
  @rules_response_header ?E

  def request() do
    A2S.Packet.create(:simple, @rules_challenge_header, <<-1::signed-32-little>>)
  end

  def parse(packet) do
    dbg("Parsing rules packet: #{inspect(packet)}")
  end

  def get_rules_header, do: @rules_challenge_header
  def get_rules_response_header, do: @rules_response_header
end
