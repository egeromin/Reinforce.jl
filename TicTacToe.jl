module TicTacToe

using Random

function allowed_next_states(current_state)
end


export display_state
function display_state(state_num)
    [parse(Int64, x) for x in string(state_num-1, base=3, pad=9)]
end


function get_lines()
    lines = zeros(Int64, 8, 3)
    lines[1:3,:] = reshape(1:9, (3, 3))
    lines[4:6,:] = transpose(lines[1:3,1:3])
    lines[7,:] = [1 5 9]
    lines[8,:] = [3 5 7]

    lines
end


export get_winner
function get_winner(state)
    lines = get_lines()

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


function get_legal_moves(state, player)
    empty_indices = [x for x in 1:9 if state[x] == 0]

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
    legal_moves = get_legal_moves_ind(state_ind, player)
    if length(legal_moves) == 0
        return -1   # sign for 'finished'
    end
    rand(legal_moves)
end


function make_move(state_ind, current_values, player)
    next_moves = get_legal_moves_ind(state_ind, player)
    if length(next_moves) == 0
        return -1
    end
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



function find_completing(state, line)
    completing = 0
    one_counts = 0
    empty_counts = 0
    for ind in line
        if state[ind] == 1
            one_counts += 1
        elseif state[ind] == 0
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


function slightly_clever_teacher_opponent(state_ind)
    state = display_state(state_ind)
    lines = get_lines()

    for line_ind in 1:size(lines, 1)
        line = lines[line_ind,:]
        completing = find_completing(state, line)
        if completing > 0
            next_state = copy(state)
            next_state[completing] = 2
            return compute_index(next_state)
        end
    end

    random_move(state_ind, 2)
end


function update_values!(values, alpha, exploiting_moves)
    #print("updating for this game: ")
    for state_pairs in exploiting_moves
        state_ind, next_state_ind = state_pairs
        # print(values[state_ind])
        # print(" -> ")
        values[state_ind] = values[state_ind] + alpha * (values[next_state_ind] - values[state_ind])
        # print(values[state_ind])
        # print(", ")

        if (state_ind, next_state_ind) == (6861, 8319)
            println("OK!!")
        end
    end
end


function play_game!(current_values, alpha)
    state_ind = random_move(1, 2)  # starting state, make a random opponent move on the empty board
    me = 1
    opponent = 2
    move_num = 1

    exploiting_moves = []

    # want to update moving between states that I'm in as a player
    # I need to choose if I want to optimise for an 'opponent' player or an initial player

    # possible situations:
    # the game finishes prematurely: no learning
    # the game finishes normally: perform the updates
    # but over the correct pairs!

    while true
        exploring = rand(1:10) == 1
        if !exploring
            next_state_ind = make_move(state_ind, current_values, me)

            if next_state_ind == -1
                exploiting_moves = []
                break
            elseif get_winner_ind(next_state_ind) > 0
                push!(exploiting_moves, (state_ind, next_state_ind))
                break
            end
        else
            next_state_ind = random_move(state_ind, me)
            if next_state_ind == -1
                exploiting_moves = []
                break
            elseif get_winner_ind(next_state_ind) > 0
                push!(exploiting_moves, (state_ind, next_state_ind))
                break
            end
        end

        next_state_ind = slightly_clever_teacher_opponent(next_state_ind)
        push!(exploiting_moves, (state_ind, next_state_ind))
        if next_state_ind == -1
            exploiting_moves = []
            break
        elseif get_winner_ind(next_state_ind) > 0
            break
        end

        state_ind = next_state_ind
    end

    if length(exploiting_moves) > 0
        update_values!(current_values, alpha, exploiting_moves)
    end

end

# todo: return value difference? For convergence test.


function train(alpha, num_games)
    srand(345)
    values = initial_values()
    for i in 1:num_games
        play_game!(values, alpha)
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

end
