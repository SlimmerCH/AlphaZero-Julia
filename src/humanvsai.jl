include("AlphaZero.jl")



learning_rate = 0.01

MCTS_ITERATIONS = 3000
DIAGRAM_REFRESH_RATE = 20
c = 2.4
t = 1.3

prepare()

while true

    global game, query_function, model, optimizer, search_values, c, t, move_count

    search_values = []

    while true 

        greedy_move(MCTS_ITERATIONS, DIAGRAM_REFRESH_RATE, c, t)

        game |> display_position
        winner = game |> get_winner

        if winner != 2 # if the game ends
            break
            println("Game ends.")
        end 

        while !user_move(game)
        end
        
        game |> display_position
        winner = game |> get_winner
        if winner != 2 # if the game ends
            break
            println("Game ends.")
        end # if the game ends
    end
    sleep(10)
    game = ConnectFour()

    println("\u001b[0m")
end