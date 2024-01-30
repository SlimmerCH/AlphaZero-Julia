
module mcts

    export MCTS, search, get_policy, get_state_value, display_tree

    include("node.jl")
    using .node

    use_state_for_eval = true

    mutable struct MCTS

        root::Node
        selection::Node

        # Function has to return a vector with all actions for a given state.
        # It is essential that the order is deterministic
        action_space_function::Function

        # Function has to return the new state for a given action AND update the state object.
        transition_function::Function

        # Function has to return the score of a game state.
        game_state_function::Function

        # Function has to parse the game state and output its policy and value
        # p, v = f(x)
        neural_network

        # Symbols for the game state function are as follows:
        # -1 -> Second player wins
        #  0 -> Draw
        #  1 -> First player wins
        #  2 -> Game is not finished

        # Exploration rate
        c_puct::Float16

        # Temperature for further control of exploration
        t::Float16

        # Data type of a state
        state_data_type::DataType

        # Data type of a action
        action_data_type::DataType

        # Keep track of the selection route
        visited_nodes::Vector{Node}

        # Action space
        action_space::Vector

        # Store the result of the latest rollout
        v::Float32


        function MCTS(
            state::Any,
            action_space_function::Function,
            transition_function::Function,
            game_state_function::Function,
            neural_network,
            c_puct=1.41,
            t=1,
            state_data_type::DataType=Any,
            action_data_type::DataType=Any
        )
            
            # Data type of a state
            set_state_data_type(state_data_type)

            root::Node = Node(state)
            action_space::Vector = action_space_function(state)
            visited_nodes::Vector = []
            initial_value = 0

            new(
                root,
                root,
                action_space_function,
                transition_function,
                game_state_function,
                neural_network,
                Float16(c_puct),
                Float16(t),
                state_data_type,
                action_data_type,
                visited_nodes,
                action_space,
                initial_value
            )
        end

    end



    #############################
    #                           #
    #       Public Methods      #
    #                           #
    #############################

    # search
    function search(mcts::MCTS, iterations::Integer)
        if mcts.neural_network === undef
            # Classical MCTS
            for _ in 1:iterations
                _selection(mcts)
                _expansion(mcts)
                _rollout(mcts)
                _backpropagation(mcts)
            end
        else
            # AlphaZero-based MCTS
            for _ in 1:iterations
                _selection(mcts)
                _expansion(mcts, true)
                _evaluation(mcts)
                _backpropagation(mcts)
            end
        end
    end

    # calculate the policy
    function get_policy(mcts::MCTS)
        visits::Vector = [node.N for node in mcts.root.children]
        # Normalize the visits
        probability = visits / sum(visits)
        if mcts.t != 1
            probability = probability .^ (1/mcts.t)
            probability = probability / sum(probability)
        end
        return [_get_policy_labels(mcts), probability]
    end
    
    function get_state_value(mcts::MCTS)
        V::Float32 = mcts.root.V
        N::UInt32 = mcts.root.N
        return V / N
    end
    
    # displeay the tree (sort of)
    function display_tree(mcts::MCTS)
        println("Root:\t\t 1")
        for (i, n_nodes) = _print_node_branch(mcts.root) |> enumerate
            println("Layer "*string(i)*":\t "*string(n_nodes))
        end
        
    end
    
    
    #############################
    #                           #
    #      Private Methods      #
    #                           #
    #############################
    
    function _selection(mcts::MCTS)

        mcts.visited_nodes = [mcts.root]
        mcts.selection = mcts.root

        while !is_leaf(mcts.selection)
            children::Vector{Node} = mcts.selection.children
            QUvalues::Vector{Float32} = map(
                node::Node -> get_QU(node, mcts.selection.N, mcts.c_puct),
                children
            )
            mcts.selection = children[argmax(QUvalues)]
            push!(mcts.visited_nodes, mcts.selection)
        end
        
    end

    function _expansion(mcts::MCTS, include_p::Bool=false)

        action_space::Vector{mcts.action_data_type} = mcts.action_space_function(mcts.selection.state)
        if include_p
            P, v = mcts.neural_network(mcts.selection.state)
        end
        
        for action::mcts.action_data_type in action_space
            new_state = deepcopy(mcts.selection.state)
            mcts.transition_function(new_state, action)
            
            p = include_p ? P[action] : undef
            expand_node(mcts.selection, new_state, p)
        end

        if isempty(mcts.selection.children)
            return
        end

        mcts.selection = rand(mcts.selection.children)

    end

    function _rollout(mcts::MCTS)
        is_leaf(mcts.selection) || error("Current selection is not a leaf node.")

        simulation = deepcopy(mcts.selection.state)

        state::Int8 = mcts.game_state_function(simulation)
        while state == 2
            action_space::Vector{mcts.action_data_type} = mcts.action_space_function(simulation)
            if length(action_space) > 0
                mcts.transition_function(simulation, rand(action_space))
            end
            state = mcts.game_state_function(simulation)
        end
        mcts.v = state
        
    end

    function _evaluation(mcts::MCTS)
        
        is_leaf(mcts.selection) || error("Current selection is not a leaf node.")

        reward = mcts.selection.state |> mcts.game_state_function

        if reward == 2 || !use_state_for_eval
            P, v =  mcts.neural_network(mcts.selection.state)
            if mcts.selection.state.pt != mcts.root.state.pt
                v *= -1
            end

            
            mcts.v = v
            

        else
            mcts.v = reward
        end

    end


    function _backpropagation(mcts::MCTS)
        for node::Node in mcts.visited_nodes
            node.N += 1
            node.V += mcts.v
        end
    end

    # recursive stuff for display_tree
    function _print_node_branch(node::Node)

        sum = []
        sums = [_print_node_branch(n) for n in node.children]

        if length(sums) > 0
            max::UInt8 = length(sums[argmax(length.(sums))])
            sum = [Int16(0) for i in 1:max]
            for elm in sums
                append!(elm, [Int16(0) for i in 1:max-length(elm)])
                sum += elm
            end
            return vcat([length(sums)], sum)
        else
            return []
        end
    end

    function _get_policy_labels(mcts::MCTS)
        return mcts.action_space
    end

end