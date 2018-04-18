module TicTacToe

using Random

function allowed_next_states(current_state)
end


export display_state
function display_state(state_num)
    [parse(Int64, x) for x in string(state_num-1, base=3, pad=9)]
end


export get_winner
function get_winner(state)
    lines = zeros(Int64, 8, 3)
    lines[1:3,:] = reshape(1:9, (3, 3))
    lines[4:6,:] = transpose(lines[1:3,1:3])
    lines[7,:] = [1 5 9]
    lines[8,:] = [3 5 7]

    function single_color(line_ind)
        line = lines[line_ind,:]
        if (state[line[1]] == state[line[2]]) && (state[line[2]] == state[line[3]])
            return state[line[1]]
        end
        return 0
    end

    winners = Set(single_color(line_ind) for line_ind in 1:size(lines, 1))
    maximum(winners)
end


function get_winner_ind(state_ind)
    get_winner(display_state(state_ind))
end


function initial_value(state)
    winner = get_winner(state)

    if winner == 2
        0.0
    elseif winner == 1
        1.0
    else
        0.5
    end

end


function initial_values()
    [initial_value(display_state(i)) for i in 1:3^9]
end


mutable struct FullBoardError <: Exception end

function get_legal_moves(state, player)
    empty_indices = [x for x in 1:9 if state[x] == 0]

    if size(empty_indices)[1] == 0
        throw(FullBoardError())
    end

    legal_moves = []
    for ind in empty_indices
        next_state = copy(state)
        next_state[ind] = player
        push!(legal_moves, next_state)
    end

    legal_moves
end


function compute_index(state)
    state_ind = 0
    for i in 1:9
        state_ind += state[i] * 3 ^ (9-i)
    end
    state_ind + 1
end

@assert compute_index(display_state(5)) == 5


function get_legal_moves_ind(state_ind, player)
    state = display_state(state_ind)
    legal_moves = get_legal_moves(state, player)
    [compute_index(next_state) for next_state in legal_moves]
end

function random_move(state_ind, player)
    rand(get_legal_moves_ind(state_ind, player))
end


function make_move(state_ind, current_values, player)
    next_moves = get_legal_moves_ind(state_ind, player)
    next_values = [current_values[next_move] for next_move in next_moves]
    _, max_index = findmax(next_values)
    next_moves[max_index]
end


function pprint_state(state_ind)
    state = reshape(display_state(state_ind), (3, 3))
    for i in 1:size(state, 1)
        println(state[:,i])
    end
end


function play_game!(current_values, alpha, first_player)
    state_ind = 1  # starting state, empty board
    player = first_player
    move_num = 1
    while get_winner_ind(state_ind) == 0
        # pprint_state(state_ind)
        try
            if player == 1 && move_num % 10 != 0
                next_state_ind = make_move(state_ind, current_values, player)
            else
                next_state_ind = random_move(state_ind, player)
            end

            # if player == 1
            # println(current_values[state_ind])
            current_values[state_ind] = current_values[state_ind] + alpha * (current_values[next_state_ind] - current_values[state_ind])
            # println(current_values[state_ind])
            # end

            state_ind = next_state_ind
            move_num += 1
            player = 3 - player

        catch y
            if isa(y, FullBoardError)
                break
            else
                rethrow(y)
            end
        end
    end
    # pprint_state(state_ind)
    # println(current_values[state_ind])
end

# todo: return value difference? For convergence test.


function train(alpha, num_games)
    srand(345)
    values = initial_values()
    first_player = 1
    for i in 1:num_games
        play_game!(values, alpha, first_player)
        first_player = 3 - first_player
    end

    values
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
    player = 1
    state_ind = 1
    while get_winner_ind(state_ind) == 0
        try
            if player == 1
                next_state_ind = make_player_move(state_ind, player)
            else
                next_state_ind = make_move(state_ind, values, player)
            end

            state_ind = next_state_ind
            player = 3 - player

        catch y
            if isa(y, FullBoardError)
                break
            else
                rethrow(y)
            end
        end
    end
end

end
