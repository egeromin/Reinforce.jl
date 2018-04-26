module TicTacToe

using Random
import Base.show
import Printf.@sprintf

@enum Player nobody me opponent
BOARD_SIZE = 9


struct Board
    cells::Array{Player, 1}

    Board(cells) = new(copy(cells))  # copy by default on constructing
    Board() = new(repeat([nobody], BOARD_SIZE))
end


function board_from_index(i::Int64)
    Board([Player(parse(Int64, x)) for x in string(i-1, base=3, pad=9)])
end


function get_lines()
    lines = zeros(Int64, 8, 3)
    lines[1:3,:] = reshape(1:9, (3, 3))
    lines[4:6,:] = transpose(lines[1:3,1:3])
    lines[7,:] = [1 5 9]
    lines[8,:] = [3 5 7]

    lines
end


LINES = get_lines()


function get_winner(board::Board)

    for i in 1:size(LINES, 1)
        line = LINES[i, :]
        a, b, c = map(j -> board.cells[j], line)
        if a == b == c
            return a
        end
    end

    return nobody

end


function get_winner_index(i)
    get_winner(board_from_index(i))
end


function is_board_full(board::Board)
    all(board.cells .!= [nobody])
end


function initial_value(board::Board, player::Player)
    winner = get_winner(board)

    if winner == player
        1.0
    elseif winner != nobody
        0.0
    elseif is_board_full(board)
        1.0
    else
        0.5
    end

end


function initial_values(player::Player)
    [initial_value(board_from_index(i), player) for i in 1:3^9]
end


function get_legal_moves(board::Board, player::Player)
    function put_down_player(i::Int64)
        new_board = Board(board.cells)
        new_board.cells[i] = player
        return new_board
    end

    [put_down_player(i) for (i, current) in enumerate(board.cells) if current == nobody]
end


function index_from_board(board::Board)::Int64
    state_ind = 0
    for i in 1:9
        state_ind += Int64(board.cells[i]) * 3 ^ (9-i)
    end
    state_ind + 1
end


@assert index_from_board(board_from_index(5)) == 5

#
# function get_legal_moves_index(i::Int64, player::Player)
#     board = board_from_index(i)
#     legal_moves = get_legal_moves(board, player)
#     [index_from_board(next_state) for next_state in legal_moves]
# end
#

function random_move(b::Board, player::Player)
    rand(get_legal_moves(b, player))
end


"""
All the data for a learned model:

- the values
"""
struct Model
    values::Array{Float64, 1}
    player::Player
    Model(player) = new(initial_values(player), player)
end


function make_move(model::Model, board::Board, player::Player)
    next_moves = get_legal_moves(board, player)
    next_values = [model.values[index_from_board(next_move)] for next_move in next_moves]
    _, max_index = findmax(next_values)
    next_moves[max_index]
end


function pprint_state(board::Board)
    # board = board_from_index(i)
    board_reshaped = reshape(board.cells, (3,3))
    for i in 1:3
        for j in 1:3
            player = board_reshaped[i, j]
            if player == me
                print('X')
            elseif player == opponent
                print('O')
            else
                print('.')
            end
        end
        print('\n')
    end

    println("\n--------------\n")
end


function find_completing(board::Board, line::Array{Int64, 1}, player::Player)
    completing = 0
    player_counts = 0
    nobody_counts = 0
    for i in line
        if board.cells[i] == player
            player_counts += 1
        elseif board.cells[i] == nobody
            completing = i
            nobody_counts += 1
        end
    end

    if player_counts == 2 && nobody_counts == 1
        return completing
    else
        return 0
    end
end

"""
This player completes 2 in a row, otherwise returns a fallback
"""
function complete_2_in_a_row(board::Board, player::Player, fallback_move)
    for i in 1:size(LINES, 1)
        line = LINES[i, :]
        completing = find_completing(board, line, player)
        if completing > 0
            next_state = Board(board.cells)
            next_state.cells[completing] = player
            return next_state
        end
    end

    other_player = player == opponent ? me : opponent
    for i in 1:size(LINES, 1)
        line = LINES[i, :]
        completing = find_completing(board, line, other_player)
        if completing > 0
            next_state = Board(board.cells)
            next_state.cells[completing] = player
            return next_state
        end
    end

    fallback_move(board, player)
end


"""
Completes 2 in a row if that's the case, otherwise returns
a random move
"""
function slightly_clever_teacher_opponent(board::Board)
    complete_2_in_a_row(board, opponent, random_move)
end


"""
Tries to match the current board to 'pattern' by rotating 0, 90, 180, 270 degrees.
If it finds a match, returns next correctly rotated.
Otherwise, returns nothing.
"""
function next_from_pattern(board::Board, pattern::Board, next::Board)
    board_cells = reshape(board.cells, (3, 3))
    pattern_cells = reshape(pattern.cells, (3,3))
    next_cells = reshape(next.cells, (3,3))

    for i in 0:3
        if board_cells == pattern_cells
            next_rotated = rotr90(next_cells, i)
            return Board(reshape(next_rotated, BOARD_SIZE))
        end
        board_cells = rotl90(board_cells)
    end

    nothing  # return nothing if there's no match
end

"""
Rule based play for an opponent.

If none of the rules apply, raises an error
"""
function rule_based_play(board::Board)
    num_nonempty = sum(board.cells .!= [nobody])

    pattern_next = []

    if num_nonempty == 0
        next_board = Board()
        next_board.cells[5] = opponent  # fill in the middle
        return next_board
    elseif num_nonempty == 2
        pattern_next = [
            (
                Board([
                    nobody, nobody, me,
                    nobody, opponent, nobody,
                    nobody, nobody, nobody
                    ]),
                Board([
                    nobody, nobody, me,
                    nobody, opponent, opponent,
                    nobody, nobody, nobody
                    ])
            ),
            (
                Board([
                    nobody, me, nobody,
                    nobody, opponent, nobody,
                    nobody, nobody, nobody
                    ]),
                Board([
                    nobody, me, opponent,
                    nobody, opponent, nobody,
                    nobody, nobody, nobody
                    ]),
            ),
        ]  # pattern-next pairs
    elseif num_nonempty == 4
        pattern_next = [
            (
                Board([
                    nobody, nobody, me,
                    me, opponent, opponent,
                    nobody, nobody, nobody
                    ]),
                Board([
                    nobody, opponent, me,
                    me, opponent, opponent,
                    nobody, nobody, nobody
                    ])
            ),
            (
                Board([
                    nobody, me, opponent,
                    nobody, opponent, nobody,
                    me, nobody, nobody
                    ]),
                Board([
                    nobody, me, opponent,
                    nobody, opponent, opponent,
                    me, nobody, nobody
                    ])
            ),
        ]  # pattern-next pairs
    else
        @assert num_nonempty == 6
        pattern_next = [
            (
                Board([
                    nobody, opponent, me,
                    me, opponent, opponent,
                    nobody, me, nobody
                    ]),
                Board([
                    opponent, opponent, me,
                    me, opponent, opponent,
                    nobody, me, nobody
                    ])
            )
        ]  # pattern-next pairs
    end

    for i in pattern_next
        pattern, next = i
        match = next_from_pattern(board, pattern, next)
        if match !== nothing
            return match
        end
    end

    error("No matching rules found!")

end


function perfect_opponent(board::Board)
    complete_2_in_a_row(board, opponent, (b, p) -> rule_based_play(b))
end


function update_values!(model::Model, alpha::Float64, exploiting_moves::Array{Int64, 1})
    for i in 2:length(exploiting_moves)
        a = exploiting_moves[i-1]
        b = exploiting_moves[i]
        model.values[a] = model.values[a] + alpha * (model.values[b] - model.values[a])
    end
end


"""
Make a learner move: do an exploring move with probability exploration_prob
And otherwise make an exploiting move
"""
function learner_move!(model::Model, board::Board, player::Player, exploiting_moves::Array{Array{Int64, 1}, 1}, exploration_prob::Float64)
    if rand(Float64, 1)[1] < exploration_prob
        board = random_move(board, player)
        push!(exploiting_moves, [])
    else
        board = make_move(model, board, player)
    end

    push!(exploiting_moves[end], index_from_board(board))
    return board
end


# todo: return value difference? For convergence test.
function train_game!(model_me::Model, model_opponent::Model, alpha::Float64, exploration_prob::Float64)
    @assert model_me.player == me
    @assert model_opponent.player == opponent
    exploiting_moves_me::Array{Array{Int64, 1}, 1} = [[]]
    exploiting_moves_opponent::Array{Array{Int64, 1}, 1} = [[]]
    board = Board()
    current_player = opponent
    while true
        winner = get_winner(board)
        if winner != nobody
            break
        end
        if is_board_full(board)
            break
        end

        if current_player == opponent
            board = learner_move!(model_opponent, board, current_player, exploiting_moves_opponent, exploration_prob)
            current_player = me
        else
            board = learner_move!(model_me, board, current_player, exploiting_moves_me, exploration_prob)
            current_player = opponent
        end
    end

    last_index = index_from_board(board)
    if exploiting_moves_me[end][end] != last_index
        push!(exploiting_moves_me[end], last_index)
    end
    if exploiting_moves_opponent[end][end] != last_index
        push!(exploiting_moves_opponent[end], last_index)
    end

    for moves in exploiting_moves_me
        update_values!(model_me, alpha, moves)
    end

    for moves in exploiting_moves_opponent
        update_values!(model_opponent, alpha, moves)
    end

end



function train!(model_me::Model, model_opponent::Model, alpha::Float64, exploration_prob::Float64, num_games::Int64)
    # srand(345)  # random seed
    for i in 1:num_games
        train_game!(model_me, model_opponent, alpha, exploration_prob)
    end
end


function print_move(state_ind)
    print(state_ind)
    print(": \n")
    pprint_state(state_ind)
    print("\n\n")
end


function play_game(model::Model)
    board = Board()
    current_player = opponent
    while true
        winner = get_winner(board)
        if winner != nobody
            return winner
        end
        if is_board_full(board)
            return nobody
        end

        if current_player == opponent
            board = perfect_opponent(board)
            current_player = me
        else
            board = make_move(model, board, current_player)
            current_player = opponent
        end
    end
end


struct Stats
    wins::Float64
    draws::Float64
    losses::Float64
end


"""
Override 'show' for 'Stats'
"""
function Base.show(io::IO, stats::Stats)
    out_str = @sprintf("\nWins: %.2f%%\nDraws: %.2f%%\nLosses: %.2f%%\n",
        stats.wins * 100, stats.draws * 100, stats.losses * 100)
    print(out_str)  # Show vs print?
end


function success_rate(model::Model, num_games::Int64)

    num_wins = 0
    num_draws = 0
    for i in 1:num_games
        winner = play_game(model)
        if winner == me
            num_wins += 1
        elseif winner == nobody
            num_draws += 1
        end
    end

    return Stats(num_wins / num_games, num_draws / num_games, (num_games - num_wins - num_draws) / num_games)
end

end  # module


"""
- main function: computes a success metric
- trains once over 1000 games & then plays another 1000 games and outputs the success rate
"""
function main()
    model_me = TicTacToe.Model(TicTacToe.me)
    model_opponent = TicTacToe.Model(TicTacToe.opponent)
    TicTacToe.train!(model_me, model_opponent, 0.3, 0.3, 300000)
    println("Training done")

    for i in 1:10
        println("Test run $i of 10")
        print(TicTacToe.success_rate(model_me, 1000))
    end

    # println("HIghest ranking board states: ")
    # values_enumerated = [x for x in enumerate(model.values)]
    # values_enumerated = sort(values_enumerated, by=x->x[2])
    # for pair in values_enumerated
    #     if pair[2] == 1.0
    #         break
    #     end
    #     println(pair)
    #     TicTacToe.pprint_state(TicTacToe.board_from_index(pair[1]))
    #     println("\n-------\n")
    # end
end

main()