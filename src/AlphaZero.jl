include("Games/connectfour.jl")
include("MCTS/mcts.jl")
include("NeuralNetwork/neuralnetwork.jl")

using .connectfour
using .mcts
using .neuralnetwork
using ProgressMeter
import Plots
using BSON: @save, @load
using Random


        #############################
        #                           #
        #       Private Methods     #
        #                           #
        #############################

# NN
const dimension = (6, 7)
const in_channels = 3
const hidden_layer_size = 128
const resblocks = 4
const policy_outputs = dimension[2]
global move_count

function _UInt_to_plane(uint)
    len = prod(dimension)
    bin_str = bitstring(uint)[end-len+1:end]
    bin_arr = [
        parse(Bool, bin_str[i]) |> Float32
        for i in eachindex(bin_str)
    ]
    reshape_arr = reshape(bin_arr, dimension...)
    return reshape_arr
end

function _value_to_plane(value)
    float::Float32 = value |> Float32
    return fill( float, dimension )
end

function _parse_game(game)
    input = cat(
        game.yellows |> _UInt_to_plane, 
        game.reds |> _UInt_to_plane,
        game.pt |> _value_to_plane,
        dims = 3
    )
    return reshape(input, (size(input)..., 1)) |> gpu
end

function _index_to_move(index)
    # We can use the index to determine the target column.
    return index - 1 # Julias array indexing starts at 1.
end

function _get_query_function(nn::NeuralNetwork)

    function query(game::ConnectFour)

        state = deepcopy(game)
        if !game.pt
            state = state |> _mirror_board
        end

        input = state |> _parse_game

        P, v = nn(input) |> cpu
        P, v = dropdims(P, dims=2), v[1]

        action_space = get_legal_moves(state)
        
        P_dict = Dict{Any, Float32}()

        for (i, p) in enumerate(P)
            move = i |> _index_to_move
            if move in action_space
                P_dict[move] = p
            end
        end

        return P_dict, v

    end

    return query
end

function _mirror_board(game::ConnectFour)
    c = deepcopy(game)
    c.reds = deepcopy(game.yellows)
    c.yellows = deepcopy(game.reds)
    return c
end

function _silent_search(iterations, c = 2, t=1)

    global game
    global query_function
    global search_values

    tree = MCTS(
        game,
        connectfour.get_legal_moves,
        connectfour.move,
        connectfour.get_reward_function(game.pt),
        query_function,
        c,
        t,
        connectfour.ConnectFour,
        Int8
    )
    search(tree, iterations)
end


function _select_move(policy)
    moves = collect(keys(policy))
    probabilities = collect(values(policy))
    cumulative_probabilities = cumsum(probabilities)
    random_value = rand()
    for (i, cumulative_probability) in enumerate(cumulative_probabilities)
        if random_value <= cumulative_probability
            return moves[i]
        end
    end
end

        #############################
        #                           #
        #       Public Methods      #
        #                           #
        #############################

function prepare(lr=0)
    global game, move_count, query_function, nn

    
    game = ConnectFour()

    @info "Preparing neural network"

    println("  - Preparing topology...\t[1/2]")

    nn = NeuralNetwork(dimension, in_channels, hidden_layer_size, resblocks, policy_outputs)

    if isfile("model.bson")
        @load "model.bson" model optimizer move_count
        model, optimizer = model |> gpu, optimizer |> gpu
        nn.model = model
        nn.optimizer = optimizer
    else
        move_count = 0
    end
    set_learning_rate(nn, lr)

    println("  - Preparing query function...\t[2/2]")

    query_function = _get_query_function(nn)
    query_function(game) # Query with dummy inputs to precompile the necessary functions

    println("\033[1mDone!\n")


    @info "Preparing Monte Carlo Tree Search..."

    tree = MCTS(
        game,
        connectfour.get_legal_moves,
        connectfour.move,
        connectfour.get_reward_function(game.pt),
        query_function,
        2,
        1,
        connectfour.ConnectFour,
        Int8
    )

    search(tree, 10)
    moves, probability = get_policy(tree)
    columns = map(x -> string(x+1), moves)
    bar = Plots.bar(columns, probability, xlabel="Move Probability", ylabel="Columns", title="Monte Carlo Tree Search", legend=false, color="orange")

    println("\033[1mDone!\n")
    print("\nTotal Iterations: ")
    println(move_count)
end

function tree_search(iterations, refresh_rate = 50, c = 2, t=1, sv=true)

    global game
    global query_function
    global search_values

    tree = MCTS(
        game,
        connectfour.get_legal_moves,
        connectfour.move,
        connectfour.get_reward_function(game.pt),
        query_function,
        c,
        t,
        connectfour.ConnectFour,
        Int8
    )

    for i in 1:div(iterations, refresh_rate)
        search(tree, refresh_rate)
        moves, probability = get_policy(tree)
        columns = map(x -> string(x+1), moves)
        value = round(get_state_value(tree), digits = 3)

        bar = Plots.bar(columns, probability, ylim = (0, 1), xlabel="Move Probability", ylabel="Columns", title="v = "*string(value), legend=false, color="orange")
        if sv
            value_history = Plots.plot(search_values, ylim = (-1.2, 1.2))
            p = Plots.plot(bar, value_history, size = (1200, 600))
            Plots.display(p)
        else
            Plots.display(bar)
        end
        

    end
    # for debugging
    # display_tree(tree)
    moves, probability = get_policy(tree)
    policy = Dict(zip(moves, probability))

    value = round(get_state_value(tree), digits = 3)
    if !game.pt
        value *= -1
    end

    return policy, value
end

function selfplay(states, policies, search_values, true_values, c, t)
    global game, move_count
    while true
        game |> display_position
        winner = game |> get_winner
        if winner != 2 # if the game ends...
            break
        end

        policy, value = tree_search(MCTS_ITERATIONS, DIAGRAM_REFRESH_RATE, c, t)

        state = deepcopy(game)
                    
        move_count += 1

        push!(states, state)
        push!(policies, policy)
        push!(search_values, value)
        push!(true_values, game.pt ? 1 : -1) # Keep track of the player turns, wich will later be converted to the rewards based on the games outcome
        move(game, _select_move(policy))
    end
end

function greedy_move(iterations, refresh_rate = 50, c = 2, t=1, sv=true)
    policy, value = tree_search(MCTS_ITERATIONS, DIAGRAM_REFRESH_RATE, c, t)
    push!(search_values, value)
    move(game, greedy_policy(policy))
end

function greedy_policy(policy)
    moves = collect(keys(policy))
    probabilities = collect(values(policy))
    max_index = argmax(probabilities)
    return moves[max_index]
end

function benchmark(c, t)
    global game, MCTS_ITERATIONS, DIAGRAM_REFRESH_RATE
    while true
        game |> display_position
        winner = game |> get_winner
        if winner != 2 # if the game ends...
            break
        end

        policy, value = tree_search(MCTS_ITERATIONS, DIAGRAM_REFRESH_RATE, c, t)

        state = deepcopy(game)

        if rand(1:4) == 1
            @time _silent_search(MCTS_ITERATIONS, c, t)
        end

        move(game, _select_move(policy))
    end
end

function train_model(states, policies, true_values)
    global game, move_count
    print("Total Iterations: ")
    println(move_count)
    println("\033[1;38;5;208m[ Training: ")
    winner = game |> get_winner
    true_values .*= winner #convert player turns into rewards
    values = map(Float32, true_values) #gpu works with Float32

    # generate training sets
    train_data = []
    for i in eachindex(values)
        input = states[i] |> _parse_game |> gpu
        policy = zeros(Float32, 7)
        for (index, probability) in policies[i]
            policy[index+1] = probability
        end
        output = (policy, [values[i]]) |> gpu
        push!(train_data, (input, output))
    end

    train_data |> gpu

    train(nn, train_data, 2)

    # update query function
    query_function = _get_query_function(nn)
end

function save_parameters(nn)
    global move_count
    # BSON objects lose mutability for custom structs
    model = nn.model |> cpu
    optimizer = nn.optimizer |> cpu
    @save "model.bson" model optimizer move_count
end