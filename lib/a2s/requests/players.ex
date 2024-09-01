defmodule A2S.Requests.Players do
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

  def request() do
    <<255, 255, 255, 255, 73, 110, 102, 111, 0>>
  end
end
