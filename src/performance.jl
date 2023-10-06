include("AlphaZero.jl")


MCTS_ITERATIONS  = 4000
DIAGRAM_REFRESH_RATE = 20
c = 2
t = 1

mailbox = [
0,0,0,0,0,0,0,
0,0,0,0,0,0,0,
0,0,0,0,0,0,0,
0,0,0,0,0,0,0,
0,0,0,0,-1,0,0,
0,0,1,0,1,0,0,
]

prepare() 

game = mailbox_to_bitboard(mailbox)
game.pt = false
game |> display_position

tree_search(MCTS_ITERATIONS, DIAGRAM_REFRESH_RATE, c, t, false)

while true
    sleep(1)
end