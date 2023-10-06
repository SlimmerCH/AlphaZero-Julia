include("../Games/connectfour.jl")
using .connectfour

const RED = "\u001b[31m"
const YELLOW = "\u001b[33m"
const BLUE = "\u001b[34m"
const RESET = "\u001b[0m"

WIN_DICT = Dict(
    1 => YELLOW * "Yellow wins." * RESET,
    -1 => RED * "Red wins." * RESET,
    0 => "Draw"
)

game = ConnectFour()
game |> display_position

while true
    game |> user_move
    game |> display_position
    winner = get_winner(game)
    if winner != 2
        println(WIN_DICT[winner])
        break
    end
end

game = ConnectFour()
game |> display_position

while true
    sleep(0.5)
    moves = game |> get_legal_moves
    col = rand(moves)
    move(game, col)
    print("\033[2J")
    game |> display_position
    winner = get_winner(game)
    if winner != 2
        println(WIN_DICT[winner])
        break
    end
end