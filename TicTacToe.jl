module TicTacToe

using Random


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


function initial_value(board::Board)
    winner = get_winner(board)

    if winner == opponent
        0.0
    elseif winner == me
        1.0
    elseif is_board_full(board)
        1.0
    else
        0.5
    end

end


function initial_values()
    [initial_value(board_from_index(i)) for i in 1:3^9]
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
    Model() = new(initial_values())
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


function slightly_clever_teacher_opponent(board::Board)
    for i in 1:size(LINES, 1)
        line = LINES[i, :]
        completing = find_completing(board, line, opponent)
        if completing > 0
            next_state = Board(board.cells)
            next_state.cells[completing] = opponent
            return next_state
        end
    end

    for i in 1:size(LINES, 1)
        line = LINES[i, :]
        completing = find_completing(board, line, me)
        if completing > 0
            next_state = Board(board.cells)
            next_state.cells[completing] = opponent
            return next_state
        end
    end

    random_move(board, opponent)
end


function update_values!(model::Model, alpha::Float64, exploiting_moves::Array{Int64, 1})
    for i in 2:length(exploiting_moves)
        a = exploiting_moves[i-1]
        b = exploiting_moves[i]
        model.values[a] = model.values[a] + alpha * (model.values[b] - model.values[a])
    end
end


# todo: return value difference? For convergence test.
function train_game!(model::Model, alpha::Float64)
    exploiting_moves::Array{Int64, 1} = []
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
            board = slightly_clever_teacher_opponent(board)
            current_player = me
        else
            board = make_move(model, board, current_player)
            current_player = opponent
            push!(exploiting_moves, index_from_board(board))
        end
    end

    last_index = index_from_board(board)
    if exploiting_moves[end] != last_index
        push!(exploiting_moves, last_index)
    end

    update_values!(model, alpha, exploiting_moves)

end



function train!(model::Model, alpha::Float64, num_games::Int64)
    # srand(345)  # random seed
    for i in 1:num_games
        train_game!(model, alpha)
    end
end


function print_move(state_ind)
    print(state_ind)
    print(": \n")
    pprint_state(state_ind)
    print("\n\n")
end

function make_player_move(state_ind, player)
    while true
        legal_moves = get_legal_moves_ind(state_ind, player)

        print("Legal moves: \n")
        for move in legal_moves
            print_move(move)
        end

        input = parse(UInt, readline())

        if sum(legal_moves .== input) > 0
            return input
        else
            println("Invalid move! Sorry")
        end
    end
end

function play(values)
    player = 2
    state_ind = 1
    winner = 0
    while winner == 0
        if player == 2
            next_state_ind = make_player_move(state_ind, player)
            if next_state_ind == -1
                print("Board full!")
                break
            end
        else
            next_state_ind = make_move(state_ind, values, player)
        end

        state_ind = next_state_ind
        player = 3 - player
        winner = get_winner_ind(state_ind)
    end

    if winner == 2
        println("You win!")
    elseif winner == 1
        println("I win!")
    end

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
            board = slightly_clever_teacher_opponent(board)
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
    model = TicTacToe.Model()
    TicTacToe.train!(model, 0.5, 10000)
    println("Training done")
    print(TicTacToe.success_rate(model, 1000))

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
