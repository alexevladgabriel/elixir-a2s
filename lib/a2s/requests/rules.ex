defmodule A2S.Requests.Rules do
  @type t() :: %__MODULE__{
          count: byte(),
          rules: list({String.t(), String.t()})
        }
  defstruct [
    :count,
    :rules
  ]

  def request() do
    <<255, 255, 255, 255, 73, 110, 102, 111, 0>>
  end
end
