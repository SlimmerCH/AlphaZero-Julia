module chess

    const board_size::Int8 = 4

    const _RED = "\u001b[31m"
    const _GREEN = "\u001b[32m"
    const _BLUE = "\u001b[34m"
    const _RESET = "\u001b[0m"



    
    abstract type Bitboard end

    mutable struct Bitboard16 <: Bitboard

        # Bitboard reprensentation
        wp::UInt16
        wn::UInt16
        wb::UInt16
        wr::UInt16
        wq::UInt16
        wk::UInt16

        bp::UInt16
        bn::UInt16
        bb::UInt16
        br::UInt16
        bq::UInt16
        bk::UInt16

    end

    mutable struct Bitboard32 <: Bitboard

        # Bitboard reprensentation
        wp::UInt32
        wn::UInt32
        wb::UInt32
        wr::UInt32
        wq::UInt32
        wk::UInt32

        bp::UInt32
        bn::UInt32
        bb::UInt32
        br::UInt32
        bq::UInt32
        bk::UInt32

    end

    mutable struct Bitboard64 <: Bitboard

        # Bitboard reprensentation
        wp::UInt64
        wn::UInt64
        wb::UInt64
        wr::UInt64
        wq::UInt64
        wk::UInt64

        bp::UInt64
        bn::UInt64
        bb::UInt64
        br::UInt64
        bq::UInt64
        bk::UInt64
        
    end

    # Minichess object
    abstract type Game end

    mutable struct MicroChess <: Game

        # Bitboard for a board size of up to 4 x 4
        pos::Bitboard16
        
        # Board dimensions
        dim::NTuple{2, Int8}

        # Player turn
        pt::Bool # True if it is white's turn
        
        # Amount of half moves before the last capture or pawn move are not reqeured for Minichess
        hm::UInt16

        # Storage for positions that have been visited for the first time
        r1::Vector{Bitboard16}
        # Storage for positions that have been visited twice
        r2::Vector{Bitboard16}
        
    end

    mutable struct MiniChess <: Game
        # Bitboard for a board size of up to 5 x 6 or 4 x 8
        pos::Bitboard32
        
        # Board dimensions
        dim::NTuple{2, Int8}

        # Player turn
        pt::Bool # True if it is white's turn
        
        # Amount of half moves before the last capture or pawn move are not reqeured for Minichess
        hm::UInt16
        
        # Storage for positions that have been visited for the first time
        r1::Vector{Bitboard32}
        # Storage for positions that have been visited twice
        r2::Vector{Bitboard32}
        
    end

    mutable struct Chess <: Game

        # Bitboard for a regular 64 x 64 board
        pos::Bitboard64

        # Board dimensions
        dim::NTuple{2, Int8}

        # Player turn
        pt::Bool # True if it is white's turn
        
        # Amount of half moves before the last capture or pawn move are not reqeured for Minichess
        hm::UInt16
        
        # Storage for positions that have been visited for the first time
        r1::Vector{Bitboard64}
        # Storage for positions that have been visited twice
        r2::Vector{Bitboard64}

        # Castling rights
        cwk::Bool 
        cwq::Bool
        cbk::Bool
        cbq::Bool

        # En-passent square
        eps::UInt16
    end



        #############################
        #                           #
        #       Public Methods      #
        #                           #
        #############################

        # Returns the starting game state.
        function new_game(chess_type::String="micro")::Game

            chess_type = lowercase(chess_type)


            
            if chess_type == "micro"
                return MicroChess(Bitboard16(0x0f00, 0x8000, 0x0000, 0x1000, 0x2000, 0x4000, 0x00f0, 0x0000, 0x0001, 0x0008, 0x0002, 0x0004), (4, 4), true, 0x0000, [], [])
            elseif chess_type == "mini"
                return MiniChess(Bitboard32(0x000f8000, 0x00200000, 0x00400000, 0x00100000, 0x00800000, 0x01000000, 0x000003e0, 0x00000002, 0x00000004, 0x00000001, 0x00000008, 0x00000010), (5, 5), true, 0x0000, [], [])
            elseif chess_type == "chess"
                return Chess(Bitboard64(0x0f00, 0x8000, 0x0000, 0x1000, 0x2000, 0x4000, 0x00f0, 0x0000, 0x0001, 0x0008, 0x0002, 0x0004), (8, 8), true, 0x0000, [], [], true, true, true, true, 0)
            else
                error("Chess type not found.")
            end
            
            
        end

        # Returns an array with all valid moves
        # A move is a tuple with five integers formatted as follows:
        # (row of piece, column of piece, target row, target column, promotion piece id)
        function get_legal_moves(game::Game)::Array{NTuple{5, Int8}}
            _get_legal_moves(game.pos, game.dim, game.pt)
        end

        # Makes a move and updates the position.
        function move_piece(game::Game, move::NTuple{5, Int8})
            
            current_piece, replacement = _move_piece(game.pos, game.dim, move)

            if abs(current_piece) == 1 || replacement != 0
                game.hm = Int8(0)
                game.r1 = []
                game.r2 = []
            else
                game.hm += Int8(1)

                pos::Bitboard = deepcopy(game.pos)
                if !(game.pos in game.r1)
                    push!(game.r1, pos)
                elseif !(game.pos in game.r2)
                    push!(game.r2,pos)
                end

            end
            game.pt = !game.pt

            return game

        end

        # Returns the score if the game is finished.
        function get_winner(game::Game, legal_moves = undef)::Int8

            pos::Bitboard = game.pos

            # Score sybols are as follows:
            # -1 -> Black wins 
            #  0 -> Draw
            #  1 -> White wins
            #  2 -> Game not finished

            # Can take the legal moves as an argument to avoid redundant calculations
            if legal_moves === undef
                legal_moves = get_legal_moves(game)
            end

            # Check for a 50-move draw
            if game.hm >= 50
                return 0
            end

            # If the active player has no moves
            if length(legal_moves) == 0

                # Check if the king is being attacked
                king_position = _get_king_position(pos, game.dim, game.pt)
                if _square_is_attacked(pos, game.dim, king_position..., game.pt)
                    # If it is a check the other player wins
                    return game.pt ? Int8(-1) : Int8(1)
                else
                    # Stalemate
                    return 0
                end
            end

            # If the position has ocurred for the third time
            if pos in game.r2
                return 0
            end

            # If material on the board is insufficient for checkmating
            if pos.wp == Int8(0) && pos.wn == Int8(0) && pos.wb == Int8(0) && pos.wr == Int8(0) && pos.wq == Int8(0) && pos.bp == Int8(0) && pos.bn == Int8(0) && pos.bb == Int8(0) && pos.br == Int8(0) && pos.bq == Int8(0)
                return 0
            end

            # If there is no condition that ends the game, the game continues.
            return 2


        end

        # Returns a function that calculates the game outcome from the perspective of a given player
        function get_reward_function(player_color)::Function
            return player_color ? get_winner : _get_loser
        end

        # Prints the position. Does not display properly on all coding environments.
        # Red pieces    ->  White player
        # Green pieces  ->  Black player
        function display_position(game::Game)

            n_rows::Int8, n_cols::Int8 = game.dim
            
            horizontal::String = repeat('-', 2*n_cols) * "--" * "\n"

            string::String = horizontal
            
            for row in 0:n_rows-1
                string *= "|"
                for column in 0:n_cols-1

                    bit = row * n_cols + column
                    if (game.pos.wp >> bit) & 1 == 1
                        piece = "♟"
                        color = 1
                    elseif (game.pos.wn >> bit) & 1 == 1
                        piece = "♞"
                        color = 1
                    elseif (game.pos.wb >> bit) & 1 == 1
                        piece = "♝"
                        color = 1
                    elseif (game.pos.wr >> bit) & 1 == 1
                        piece = "♜"
                        color = 1
                    elseif (game.pos.wq >> bit) & 1 == 1
                        piece = "♛"
                        color = 1
                    elseif (game.pos.wk >> bit) & 1 == 1
                        piece = "♚"
                        color = 1
                    elseif (game.pos.bp >> bit) & 1 == 1
                        piece = "♙"
                        color = 0
                    elseif (game.pos.bn >> bit) & 1 == 1
                        piece = "♘"
                        color = 0
                    elseif (game.pos.bb >> bit) & 1 == 1
                        piece = "♗"
                        color = 0
                    elseif (game.pos.br >> bit) & 1 == 1
                        piece = "♖"
                        color = 0
                    elseif (game.pos.bq >> bit) & 1 == 1
                        piece = "♕"
                        color = 0
                    elseif (game.pos.bk >> bit) & 1 == 1
                        piece = "♔"
                        color = 0
                    else
                        piece = " "
                        color = 0
                    end

                    if Bool(color)
                        string *= _RED
                    else
                        string *= _GREEN
                    end

                    string *= piece * _RESET *" "

                end
                string *= "|\n"
            end

            string *= horizontal
            println(string)

        end

        # Converts a position from mailbox notation to a bitboard representation.
        function mailbox_notation_to_bitboard(mailbox_array::Array, chess_type::String="micro", shape::NTuple{2, Int8}=(4, 4), white_to_move::Bool=true, half_moves::Int8=Int8(0))::Game

            # The input is not case sensitive
            chess_type = lowercase(chess_type)
            
            # Integer types for the bitboard
            int_type::Dict = Dict(
                "micro" => UInt16(0),
                "mini"  => UInt32(0),
                "chess" => UInt64(0)
            )

            # The number zero with the corresponding unsigned integer
            empty = int_type[chess_type]

            dim::NTuple{2, Int8} = map(Int8, shape)

            n_rows::Int8, n_cols::Int8 = dim

            game_type::Dict = Dict(
                "micro" => MicroChess(Bitboard16(empty, empty, empty, empty, empty, empty, empty, empty, empty, empty, empty, empty), dim, white_to_move, half_moves, [], []),
                "mini"  => MiniChess(Bitboard32(empty, empty, empty, empty, empty, empty, empty, empty, empty, empty, empty, empty), dim, white_to_move, half_moves, [], []),
                "chess" => Chess(Bitboard64(empty, empty, empty, empty, empty, empty, empty, empty, empty, empty, empty, empty), dim, white_to_move, half_moves, [], [], true, true, true, true, 0)
            )

            piece_id::Dict = Dict(
                ' ' => 0,
                'P' => 1,
                'N' => 2,
                'B' => 3,
                'R' => 4,
                'Q' => 5,
                'K' => 6,
                'p' => -1,
                'n' => -2,
                'b' => -3,
                'r' => -4,
                'q' => -5,
                'k' => -6
            )

            game = game_type[chess_type]

            for (idx, piece) in enumerate(mailbox_array)
                idx -= 1
                _set_square(game.pos, dim, Int8(div(idx, n_cols)), Int8(idx % n_cols), Int8(piece_id[piece]))
            end
            return game

        end

        function UCI(move::NTuple{5, Int8}, board_shape)::String

            characters = Dict(
                 1 => 'a',
                 2 => 'b',
                 3 => 'c',
                 4 => 'd',
                 5 => 'e',
                 6 => 'f',
                 7 => 'g',
                 8 => 'h',
                 9 => 'i',
                10 => 'j',
                11 => 'k',
                12 => 'l',
                13 => 'm',
                14 => 'n',
                15 => 'o',
                16 => 'p'
            )

            promotion = Dict(
                 2 => 'n',
                 3 => 'b',
                 4 => 'r',
                 5 => 'q',
            )

            uci_move::String = characters[move[2]+1] * string(board_shape[1]-move[1]) * characters[move[4]+1] * string(board_shape[1]-move[3])

            if move[5] > 0
                uci_move *= promotion[move[5]]
            end

            return uci_move

        end

        # Resquests a uci encoded move from the user
        function user_move(game::Game, uci_move=undef)
            
            characters = Dict(
                'a' => 0,
                'b' => 1,
                'c' => 2,
                'd' => 3,
                'e' => 4,
                'f' => 5,
                'g' => 6,
                'h' => 7,
                'i' => 8,
                'j' => 9,
                'k' => 10,
                'l' => 11,
                'm' => 12,
                'n' => 13,
                'o' => 14,
                'p' => 15
            )

            promotion = Dict(
                 'n' => 2,
                 'b' => 3,
                 'r' => 4,
                 'q' => 5
            )

            move = undef

            try

                if uci_move === undef
                    print(_BLUE)
                    print("Enter move: ")
                    print(_RESET)
                    uci_move = strip(readline())
                end
                
                n_rows, n_cols = game.dim

                ccol, crow, tcol, trow, promotion_id =  (
                    Int8( characters[uci_move[1]] ),
                    Int8( n_cols - parse( Int8, uci_move[2] )),
                    Int8( characters[uci_move[3]] ),
                    Int8( n_cols - parse( Int8, uci_move[4] )),
                    Int8( 0 )
                )
                
                if length(uci_move) > 4
                    promotion_id = Int8( promotion[uci_move[5]] )
                end

                move = crow, ccol, trow, tcol, promotion_id    

            if move in get_legal_moves(game)
                move_piece(game, move)
                return true
            else
                println("Move "*uci_move*" is invalid.")
                return false
            end
            catch
                println("Move "*uci_move*" is invalid.")
                return false
            end
            

        end



        #############################
        #                           #
        #      Private Methods      #
        #                           #
        #############################

        # Returns the piece on a given square
        function _get_piece_on_square(pos::Bitboard, dim::NTuple{2, Int8}, row::Int8, column::Int8)

            n_rows::Int8, n_cols::Int8 = dim

            if !((0 <= row <= n_rows -1) && (0 <= column <= n_cols-1))
                return undef
            end

            bit = row * n_cols + column

            if (pos.wp >> bit) & 1 == 1
                return 1
            elseif (pos.wn >> bit) & 1 == 1
                return 2
            elseif (pos.wb >> bit) & 1 == 1
                return 3
            elseif (pos.wr >> bit) & 1 == 1
                return 4
            elseif (pos.wq >> bit) & 1 == 1
                return 5
            elseif (pos.wk >> bit) & 1 == 1
                return 6
            elseif (pos.bp >> bit) & 1 == 1
                return -1
            elseif (pos.bn >> bit) & 1 == 1
                return -2
            elseif (pos.bb >> bit) & 1 == 1
                return -3
            elseif (pos.br >> bit) & 1 == 1
                return -4
            elseif (pos.bq >> bit) & 1 == 1
                return -5
            elseif (pos.bk >> bit) & 1 == 1
                return -6
            else
                return 0
            end
        end

        # Returns possible squares where a given piece can move. (Without accounting for checks)
        # If include_current_square is set to false, the whole moves are returned
        function _get_targets_for_piece(pos::Bitboard, dim::NTuple{2, Int8}, row::Int8, column::Int8, include_current_square::Bool, piece_id = undef)::Array{NTuple}

            n_rows::Int8, n_cols::Int8 = dim

            if piece_id === undef
                piece_id::Int8 = _get_piece_on_square(pos, dim, row, column)
            end
            piece_type_id::Int8 = abs(piece_id)
            piece_is_white::Bool = piece_id > 0

            target_row::Int8 = 0
            target_column::Int8 = 0

            moves::Array{NTuple{5, Int8}} = []
            squares::Array{NTuple{2, Int8}} = []

            function append_moves(row::Int8, column::Int8, target_row::Int8, target_column::Int8)
                if include_current_square

                    if piece_type_id == 1 && target_row == (n_rows-1) * !piece_is_white
                        for promotion::Int8 in 2:5
                            push!(moves, (row, column, target_row, target_column, promotion))
                        end
                    else
                        push!(moves, (row, column, target_row, target_column, Int8(0)))
                    end
                else
                    push!(squares, (target_row, target_column))
                end
            end

            # Pawn
            if piece_type_id == 1

                target_row = row - 2*piece_is_white + 1
                if _get_piece_on_square(pos, dim, target_row, column) == 0
                    append_moves(row, column, target_row, column)
                end

                for column_adjustment::Int8 in -1:2:1
                    target_column = column + column_adjustment
                    target_piece = _get_piece_on_square(pos, dim, target_row, target_column)
                    if _piece_id_belongs_to_color(target_piece, !piece_is_white)
                        append_moves(row, column, target_row, target_column)
                    end
                end
            end

            # Knight
            if piece_type_id == 2

                for i::Int8 in -1:2:1

                    for j::Int8 in -1:2:1

                        for q::Bool in 0:1

                            target_row = row + 2*i - i*q
                            target_column = column + 2*j - j*!q

                            target_piece = _get_piece_on_square(pos, dim, target_row, target_column)

                            if target_piece == 0 || _piece_id_belongs_to_color(target_piece, !piece_is_white)
                                append_moves(row, column, target_row, target_column)
                            end

                        end
                    end
                end
            end

            # Bishop or Queen
            if piece_type_id == 3 || piece_type_id == 5

                for i::Int8 in -1:2:1
                    for j::Int8 in -1:2:1
                        for r::Int8 in 1:max(dim...)-1

                            target_row = row + i*r
                            target_column = column + j*r

                            target_piece = _get_piece_on_square(pos, dim, target_row, target_column)
                            target_is_capture = _piece_id_belongs_to_color(target_piece, !piece_is_white)
                            if target_piece == 0 || target_is_capture
                                append_moves(row, column, target_row, target_column)
                                if target_is_capture
                                    break
                                end
                            else
                                break
                            end

                        end
                    end
                end
            end

            # Rook or Queen
            if piece_type_id == 4 || piece_type_id == 5

                for i::Bool in 0:1
                    for j::Int in -1:2:1
                        for r::Int8 in 1:max(dim...)-1

                            target_row = row + i*j*r
                            target_column = column + !i*j*r

                            target_piece = _get_piece_on_square(pos, dim, target_row, target_column)
                            target_is_capture = _piece_id_belongs_to_color(target_piece, !piece_is_white)

                            if target_piece == 0 || target_is_capture
                                append_moves(row, column, target_row, target_column)
                                if target_is_capture
                                    break
                                end
                            else
                                break
                            end

                        end
                    end
                end
            
            end

            # King
            if piece_type_id == 6

                for i::Int8 in -1:1
                    for j::Int8 in -1:1

                        if (i, j) == (0, 0)
                            continue
                        end
                        

                        target_row = row + i
                        target_column = column + j

                        target_piece = _get_piece_on_square(pos, dim, target_row, target_column)
                        target_is_capture = _piece_id_belongs_to_color(target_piece, !piece_is_white)

                        if target_piece == 0 || target_is_capture
                            append_moves(row, column, target_row, target_column)
                        end

                    end
                end
            
            end
                        
                    
            if include_current_square
                return moves
            else
                return squares
            end

        end

        # Returns the corresponding color for a given piece id
        function _piece_id_belongs_to_color(piece_id, color::Bool)::Bool
            if piece_id == 0 || piece_id === undef
                return false
            elseif color
                return piece_id > 0
            else
                return piece_id < 0
            end
        end

        # Changes the piece that is on a given square
        function _set_square(pos::Bitboard, dim::NTuple{2, Int8}, row::Int8, column::Int8, replacement_piece::Int8)

            n_rows::Int8, n_cols::Int8 = dim

            bit = row*n_cols + column

            current_piece = _get_piece_on_square(pos, dim, row, column)

            if current_piece == 0
            elseif  current_piece == 1
                pos.wp &= ~(1 << bit)
            elseif current_piece == 2
                pos.wn &= ~(1 << bit)
            elseif current_piece == 3
                pos.wb &= ~(1 << bit)
            elseif current_piece == 4
                pos.wr &= ~(1 << bit)
            elseif current_piece == 5
                pos.wq &= ~(1 << bit)
            elseif current_piece == 6
                pos.wk &= ~(1 << bit)
            elseif current_piece == -1
                pos.bp &= ~(1 << bit)
            elseif current_piece == -2
                pos.bn &= ~(1 << bit)
            elseif current_piece == -3
                pos.bb &= ~(1 << bit)
            elseif current_piece == -4
                pos.br &= ~(1 << bit)
            elseif current_piece == -5
                pos.bq &= ~(1 << bit)
            elseif current_piece == -6
                pos.bk &= ~(1 << bit)
            end

            if replacement_piece == 0
            elseif replacement_piece == 1
                pos.wp |= (1 << bit)
            elseif replacement_piece == 2
                pos.wn |= (1 << bit)
            elseif replacement_piece == 3
                pos.wb |= (1 << bit)
            elseif replacement_piece == 4
                pos.wr |= (1 << bit)
            elseif replacement_piece == 5
                pos.wq |= (1 << bit)
            elseif replacement_piece == 6
                pos.wk |= (1 << bit)
            elseif replacement_piece == -1
                pos.bp |= (1 << bit)
            elseif replacement_piece == -2
                pos.bn |= (1 << bit)
            elseif replacement_piece == -3
                pos.bb |= (1 << bit)
            elseif replacement_piece == -4
                pos.br |= (1 << bit)
            elseif replacement_piece == -5
                pos.bq |= (1 << bit)
            elseif replacement_piece == -6
                pos.bk |= (1 << bit)
            end
            
            return current_piece
        end

        # Makes a given move for the position
        function _move_piece(pos::Bitboard, dim::NTuple{2, Int8}, move::NTuple{5, Int8})::NTuple{2, Int8}

            (current_row, current_column, target_row, target_column, promotion_piece) = move
            current_piece::Int8 = _set_square(pos, dim, current_row, current_column, Int8(0))
            replacing_piece::Int8 = current_piece
            if promotion_piece != 0
                sign::Int8 = current_piece > 0 ? Int8(1) : Int8(-1)
                replacing_piece = promotion_piece * sign
            end
            replacement = _set_square(pos, dim, target_row, target_column, replacing_piece)

            return current_piece, replacement

        end

        # Returns the position of the king
        function _get_king_position(pos::Bitboard, dim::NTuple{2, Int8}, color::Bool)::NTuple{2, Int8}

            _, n_cols::Int8 = dim


            if color
                index = trailing_zeros(pos.wk)
            else
                index = trailing_zeros(pos.bk)
            end

            row::Int8 = div(index, n_cols)
            column::Int8 = index % n_cols

            return row, column
        end

        # Checks if a piece of a given color can move on a given square
        function _square_is_attacked(pos::Bitboard, dim::NTuple{2, Int8}, row::Int8, column::Int8, color::Bool)::Bool

            sign::Int8 = color ? Int8(1) : Int8(-1)

            # King
            for square in _get_targets_for_piece(pos, dim, row, column, false, 6*sign)
                if abs(_get_piece_on_square(pos, dim, square...)) in (5, 6)
                    return true
                end
            end

            # Knight
            for square in _get_targets_for_piece(pos, dim, row, column, false, 2*sign)
                if abs(_get_piece_on_square(pos, dim, square...)) == 2
                    return true
                end
            end

            # Rook or Queen
            for square in _get_targets_for_piece(pos, dim, row, column, false, 4*sign)
                if abs(_get_piece_on_square(pos, dim, square...)) in (4, 5)
                    return true
                end
            end

            # Bishop or Queen
            for square in _get_targets_for_piece(pos, dim, row, column, false, 3*sign)
                if abs(_get_piece_on_square(pos, dim, square...)) in (3, 5)
                    return true
                end
            end

            # Pawn
            for square in _get_targets_for_piece(pos, dim, row, column, false, sign)
                if abs(_get_piece_on_square(pos, dim, square...)) == 1
                    return true
                end
            end


            return false
        end

        # Returns an array with all valid moves
        # A move is a tuple with five integers formatted as follows:
        # (row of piece, column of piece, target row, target column, promotion piece id)
        function _get_legal_moves(pos::Bitboard, dim::NTuple{2, Int8}, pt::Bool, include_checks::Bool = true)::Array{NTuple{5, Int8}}

            n_rows::Int8, n_cols::Int8 = dim

            moves::Array{NTuple{5, Int8}} = []

            for row::Int8 in 0:n_rows-1
                for column::Int8 in 0:n_cols-1

                    piece_id = _get_piece_on_square(pos, dim, row, column)
                    
                    player_owns_piece = _piece_id_belongs_to_color(piece_id, pt)

                    if !player_owns_piece
                        continue
                    end

                    append!(moves, _get_targets_for_piece(pos, dim, row, column, true))


                    if include_checks

                        function leads_to_check(move::NTuple{5, Int8})
                            new_position::Bitboard = deepcopy(pos)
                            _move_piece(new_position, dim, move)

                            king_position::NTuple{2, Int8} = _get_king_position(new_position, dim, pt)

                            if move == (3,3,2,1)
                                display_position(new_position)
                            end

                            return !_square_is_attacked(new_position, dim, king_position..., pt)
                        end

                        moves = filter(leads_to_check, moves)

                    end

                end
            end

            return moves
        end

        # Works just like get_winner with the exception that player symbols are swapped
        # This can be used to get the reward from blacks perspective
        function _get_loser(game::Game, legal_moves = undef)::Int8

            winner::Int8 = get_winner(game, legal_moves)

            # Swap the symbols if the game is finished
            if winner != 2
                winner *= -1
            end

            return winner

        end

end