module node

    # Export public methods
    export Node, set_state_data_type, is_leaf, expand_node, get_QU

    # Data type of the game states
    global state_data_type::DataType = Any

    mutable struct Node

        state::state_data_type

        N::UInt32
        V::Float64
        p::Float32

        children::Vector{Node}

        has_p::Bool

        pt::Bool

        function Node(state::state_data_type, player_turn=true)
            new(state, UInt32(0), Int32(0), Float32(0), [], false, player_turn)
        end

    end

    # Set data type of the game states
    function set_state_data_type(data_type::DataType)
        global state_data_type
        state_data_type = data_type
    end

    function is_leaf(node::Node)
        return length(node.children) == 0
    end

    function expand_node(node::Node, state::state_data_type, p = undef)
        player_turn = !node.pt
        child::Node = Node(state, player_turn)
        push!(node.children, child)
        if p != undef
            child.has_p = true
            child.p = p
        end
    end

    function get_QU(node::Node, N_parent::UInt32, c::Float16=Float16(1.41))
        if node.N == 0
            return Inf32
        end
        return _get_Q(node) + _get_U(node, N_parent, c)
    end
    
    function _get_Q(node::Node)::Float32
        return node.V / node.N
    end

    function _get_U(node::Node, N_parent::UInt32, c::Float16)::Float32
        p::Float32 = 1
        if node.has_p
            p = node.p
        end

        return Float32(p * c * (sqrt(N_parent)/(1 + node.N)))
    end

end