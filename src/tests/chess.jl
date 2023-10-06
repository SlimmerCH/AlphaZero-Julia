include("../Games/chess.jl")
using .chess

const RED = "\u001b[31m"
const GREEN = "\u001b[32m"
const BLUE = "\u001b[34m"
const RESET = "\u001b[0m"

const delay::Float16 = 0.3 

const winner_dict = Dict(
    -1 => GREEN * "Green player wins.",
    1 => RED * "Red player wins.",
    0 => BLUE * "Draw: Nobody wins.",
)

function play_random(benchmark=false)
    legal_moves::Array{NTuple{5, Int8}} = chess.get_legal_moves(game)
    score::Int8 = chess.get_winner(game, legal_moves)
    if score == 2
        rand_move::NTuple{5, Int8} = legal_moves[rand(1:length(legal_moves))]
        chess.chess.move_piece(game, rand_move)
        if (!benchmark)
            chess.display_position(game)
            sleep(delay)
        end

        return true
    else
        if (!benchmark)
            print("\n" * winner_dict[score])
            println(RESET)
        else
            global test_board
            test_board = chess.new_game("mini")
        end
        return false
    end
end

game = chess.new_game("mini")


println(BLUE * "Press Enter to Start a Game." * RESET)
while true
    readline()
    chess.display_position(game)
    sleep(delay)
    while play_random()
    end
    global game
    game = chess.new_game("mini")
end