#=

    Cleaner implementation of the original TicTacToe game.

    Using the temporal difference reinforcement learning strategy to train
    the model.

    The model is a simple array of "desirabilities" for each possible
    board state.

    There are 3 possible players:

    -

    There is a game, which takes as input an opponent and a player.

    There is a game series, which takes as input a game and the number of
    moves.

=#

module TicTacToe

struct Board
    config::Array{Int64, 1}

    Board(config) = new(copy(config))  # copy by default on constructing
end


"""
Given a state-num such as 1, output the corresponding board config
"""
function display_state(state_num::Int64)
    if state_num < 1 || state_num > 3^9
        error("$state_num is out of bounds")
    end
    Board([(parse(Int64, x) for x in string(state_num-1, base=3, pad=9)])
end


"""
Compute the index of a given board
"""
function compute_index(board::Board)
    state_ind = 0
    for i in 1:9
        state_ind += board.config[i] * 3 ^ (9-i)
    end
    state_ind + 1
end

@assert compute_index(display_state(5)) == 5


"""
Get the indices of the board corresponding to straight
lines, 8 in total (3 horizontal, 3 vertical, 2 diagonal)
"""
function get_lines()
    lines = zeros(Int64, 8, 3)
    lines[1:3,:] = reshape(1:9, (3, 3))
    lines[4:6,:] = transpose(lines[1:3,1:3])
    lines[7,:] = [1 5 9]
    lines[8,:] = [3 5 7]

    lines
end


"""
Check if there is a 'winner', i.e. a value with 3 in a row
"""
function get_winner(board::Board)
    lines = get_lines()

    function single_color(line_ind)
        line = lines[line_ind,:]
        if (board.config[line[1]] == board.config[line[2]]) && (board.config[line[2]] == board.config[line[3]])
            return board.config[line[1]]
        end
        return 0
    end

    winners = Set(single_color(line_ind) for line_ind in 1:size(lines, 1))
    maximum(winners)
end


function have_winner(board::Board)
    get_winner(board) > 0
end


"""
Compute the initial value of a given board position
"""
function initial_value(board::Board)
    winner = get_winner(board.config)

    if winner == 2
        0.0
    elseif winner == 1
        1.0
    else
        0.5
    end

end


"""
Compute the initial values for all possible board states
"""
function initial_values()
    [initial_value(display_state(i)) for i in 1:3^9]
end


"""
All the data for a learned model:

- the values
- the training parameter alpha
- the number of games it should be trained on
"""
struct LearnerModel
    values::Array{Float64, 1}
    alpha::Float64
    num_games::Int64

    LearnerModel(alpha, num_games) = new(init_values(), alpha, num_games)
end


"""
Get the legal moves, i.e. those which place a function in an empty
board position
"""
function get_legal_moves(board::Board, player)
    empty_indices = [x for x in 1:9 if board.config[x] == 0]
    if length(empty_indices) == 0
        error("Board full!")
    end

    legal_moves = []
    for ind in empty_indices
        next_board = Board(board.config)
        next_board.config[ind] = player
        push!(legal_moves, next_board)
    end

    legal_moves
end


function is_board_full(board::Board)
    all(board.config .== 0)
end


"""
The learner makes a move, based on the current values
"""
function make_learner_move(board::Board, model::LearnerModel)
    legal_moves = [compute_index(next_board) for next_board in get_legal_moves(board, 1)]
    next_values = [model.values[next_move] for next_move in legal_moves]
    _, max_index = findmax(next_values)
    display_state(legal_moves[max_index])
end


# """
# Factory for making a player
# """
# function make_learner_player(model::LearnerModel)
#     board::Board -> make_learner_move(board, model)
# end


struct Game
    player
    opponent
end


function empty_board()
    Board([0 for _ in 1:9])
end


function check_finish(move)
    winner = have_winner(move)
    if winner == 2
        print("You win!")
        return true
    elseif winner == 1
        print("I win!")
    elseif is_board_full(move)
        print("Board full!")
        return true
    end

    return false
end


function play_game(game::Game)
    move = empty_board()
    while true
        move = game.player(move)
        if check_finish(move)
            break
        end
        move = game.opponent(move)
        if check_finish(move)
            break
        end
    end
end


"""
Play to train the learner.
"""
function play_learner_game(game::Game, learner_model::LearnerModel)
    move = empty_board()
    while true
        next_move_pl = game.player(move)
        if is_board_full(next_move_pl) || have_winner(next_move_pl)
        next_move_op = game.opponent(next_move_pl)
    end
end


"""
Random move
"""
function random_move(board::Board, player)
    legal_moves = get_legal_moves(board, player)
    rand(legal_moves)
end


function find_completing(board::Board, line)
    completing = 0
    one_counts = 0
    empty_counts = 0
    for ind in line
        if board.config[ind] == 1
            one_counts += 1
        elseif board.config[ind] == 0
            completing = ind
            empty_counts += 1
        end
    end

    if one_counts == 2 && empty_counts == 1
        return completing
    else
        return 0
    end
end


"""
Semi-clever move
"""
function semi_clever(board::Board, player)
    lines = get_lines()

    for line_ind in 1:size(lines, 1)
        line = lines[line_ind,:]
        completing = find_completing(state, line)
        if completing > 0
            next_board = Board(board.config)
            next_board.config[completing] = 2
            return compute_index(next_state)
        end
    end

    random_move(state_ind, 2)
end


function train_learner(learner_model)
    
end



end
