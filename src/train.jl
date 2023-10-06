include("AlphaZero.jl")



learning_rate = 0.01

MCTS_ITERATIONS = 450
DIAGRAM_REFRESH_RATE = 40
c = 2.4
t = 1.3

prepare(learning_rate)

while true

    global game, query_function, model, optimizer, search_values, c, t, move_count

    save_parameters(nn)

    states::Vector{} = []
    policies::Vector{Dict} = []
    true_values::Vector = []
    search_values = []

    selfplay(states, policies, search_values, true_values, c, t)
    train_model(states, policies, true_values)
    
    game = ConnectFour()

    println("\u001b[0m")
end