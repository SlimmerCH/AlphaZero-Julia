module connectfour

    export ConnectFour, display_position, get_legal_moves, move, user_move, get_winner, get_reward_function, mailbox_to_bitboard

    const _RED = "\u001b[31m"
    const _YELLOW = "\u001b[33m"
    const _BLUE = "\u001b[34m"
    const _RESET = "\u001b[0m"


    # Yellow starts
    mutable struct ConnectFour
        reds::UInt64
        yellows::UInt64
        dim::NTuple{2, Int8}
        pt::Bool

        function ConnectFour(reds=UInt64(0), yellows=UInt64(0))
            new(reds, yellows, (Int8(6), Int8(7)), true)
        end

    end

    # display the position
    function display_position(game::ConnectFour)

        rows::Int8, cols::Int8 = game.dim

        horizontal::String = repeat('-', 2*cols) * "--" * "\n"

        string::String = horizontal

        for row in 0:rows-1
            string *= "|"
            for column in 0:cols-1

                bit = row * cols + column
                if (game.yellows >> bit) & 1 == 1
                    piece = _YELLOW*"⬤"*_RESET
                elseif (game.reds >> bit) & 1 == 1
                    piece = _RED * "⬤" * _RESET
                else
                    piece = " "
                end

                string *= piece * " "

            end
            string *= "|\n"
        end

        string *= horizontal
        println(string)

    end

    #return a list with all possible moves
    function get_legal_moves(game::ConnectFour)

        rows::Int8, cols::Int8 = game.dim
        moves = []

        for col in 0:cols-1
            if _get_piece_on_position(game, (col, 0)) == 0
                push!(moves, col)
            end
        end

        return moves
    end
    
    # make a move on the board
    function move(game::ConnectFour, col)

        color = game.pt ? 1 : -1
        rows, cols = game.dim

        for row in 1:rows
            if _get_piece_on_position(game, (col, row)) != 0 || row == rows
                _set_piece_on_position(game, (col, row-1), color)
                break
            end
        end
        game.pt = !game.pt
    end

    # Request the user to make a move
    function user_move(game::ConnectFour)

        print(_BLUE, "Enter move: ", _RESET)
        
        try
            col = parse(Int, strip(readline())) - 1

            if col in get_legal_moves(game)
                move(game, col)
                return true
            else
                println("Column "*col*" is illegal.")
                return false
            end

        catch
            println("Move is invalid.")
            return false
        end

    end

    # returns the Result of the game or 2 if the game has not ended yet
    function get_winner(game::ConnectFour)
        rows, cols = game.dim

        encountered_empty = false

        for row in 0:rows-1
            for col in 0:cols-1

                piece = _get_piece_on_position(game, (col, row))
                if piece == 0
                    encountered_empty = true
                    continue
                end

                for i in 0:1
                    for j in 1:-1:0

                        if i == j == 0
                            i = -1
                            j = 1
                        end

                        for q in 1:3
                            if _get_piece_on_position(game, (col + i*q, row + j*q)) != piece
                                break
                            end
                            if q == 3
                                return piece
                            end
                        end
                    end
                end
            end
        end

        return encountered_empty ? 2 : 0
    end

    # return the result based on a players perspective
    function get_reward_function(player_color)::Function
        return player_color ? get_winner : _get_loser
    end

    # convert a mailbox representation of a game state to the bitboard representation
    function mailbox_to_bitboard(mailbox)
        connectfour = ConnectFour()
        for (idx, element) in enumerate(mailbox)
            _set_piece_on_position(connectfour, _index_to_position(idx-1, connectfour.dim), element)
        end
        return connectfour
        
    end


    # opposite of get_winner
    function _get_loser(game::ConnectFour)
        winner = get_winner(game)

            # Swap the symbols if the game is finished
            if winner != 2
                winner *= -1
            end

            return winner
        
    end

    function _index_to_position(index, dim)
        rows, cols = dim
        col = index % cols
        row = div(index, cols)
        return (col, row)
    end

    function _position_to_index(position, dim)
        rows, cols = dim
        col, row = position
        return col + cols*row
    end

    # set the piece id of a certain square
    function _set_piece_on_position(game::ConnectFour, position, piece_id)
        index = _position_to_index(position, game.dim)
        if  piece_id == 1
            game.yellows |= (1 << index)
            game.reds &= ~(1 << index)
        elseif piece_id == -1
            game.reds |= (1 << index)
            game.yellows &= ~(1 << index)
        else
            game.reds &= ~(1 << index)
            game.yellows &= ~(1 << index)
        end
    end

    # return the piece id of a certain square
    function _get_piece_on_position(game::ConnectFour, position)::Int8

        rows, cols = game.dim
        col, row = position

        if !(0 <= col < cols && 0 <= row < rows)
            return 2
        end

        index = _position_to_index(position, game.dim)
        if (game.yellows >> index) & 1 == 1
            return 1
        elseif (game.reds >> index) & 1 == 1
            return -1
        else
            return 0
        end
    end

end