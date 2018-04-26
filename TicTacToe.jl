module TicTacToe

using Random
import Base.show
import Printf.@sprintf

export LearnerPolicy, PerfectPolicy, SemiCleverPolicy, RandomPolicy, train!, me, opponent, nobody, success_rate


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
        if a == b == c != nobody
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


function random_move(b::Board, player::Player)
    rand(get_legal_moves(b, player))
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




abstract type Policy end


struct RandomPolicy <: Policy
    player:: Player
end

function move!(policy::RandomPolicy, board::Board)
    random_move(board, policy.player)
end

function update!(policy::RandomPolicy, last_index::Int)
end

struct SemiCleverPolicy <: Policy 
    player:: Player
end

"""
Completes 2 in a row if that's the case, otherwise returns
a random move
"""
function move!(policy::SemiCleverPolicy, board::Board)
    complete_2_in_a_row(board, policy.player, random_move)
end


function update!(policy::SemiCleverPolicy, last_index::Int)
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

    pprint_state(board)
    print(get_winner(board))
    error("No matching rules found!")

end


struct PerfectPolicy <: Policy 
    player:: Player
end

function move!(policy::PerfectPolicy, board::Board)
    @assert policy.player == opponent
    complete_2_in_a_row(board, policy.player, (b, p) -> rule_based_play(b))
end

function update!(policy::PerfectPolicy, last_index::Int)
end


# would like to say
# player.move()  #this stores anything it might need to store
# player.update()  # this updates anything

# and a *random player* / *semi clever player* then simply don't do anything with the update
# so I have a separate 'move' and 'update' player depending on the input type
# so I want a (possible empty) abstract type which I can use to structure things


mutable struct LearnerPolicy <: Policy
    values::Array{Float64, 1}
    player::Player
    alpha::Float64
    exploration_prob::Float64
    exploiting_moves::Array{Array{Int64, 1}, 1}
    update::Bool

    LearnerPolicy(player, alpha, exploration_prob, update) = 
        new(initial_values(player), player, alpha,
            exploration_prob, [[]], update)
end


function greedy_learner_move(policy::LearnerPolicy, board::Board)
    next_moves = get_legal_moves(board, policy.player)
    next_values = [policy.values[index_from_board(next_move)] for next_move in next_moves]
    _, max_index = findmax(next_values)
    next_moves[max_index]
end


"""
Make a learner move: do an exploring move with probability exploration_prob
And otherwise make an exploiting move
"""
function move!(policy::LearnerPolicy, board::Board)
    if rand(Float64, 1)[1] < policy.exploration_prob
        board = random_move(board, policy.player)
        if policy.update
            push!(policy.exploiting_moves, [])
        end
    else
        board = greedy_learner_move(policy, board)
    end

    if policy.update
        push!(policy.exploiting_moves[end], index_from_board(board))
    end
    return board
end


function update!(policy::LearnerPolicy, last_index::Int)
    if ! policy.update
        return 
    end
    if policy.exploiting_moves[end][end] != last_index
        push!(policy.exploiting_moves[end], last_index)
    end
    for moves in policy.exploiting_moves
        for i in 2:length(moves)
            a = moves[i-1]
            b = moves[i]
            policy.values[a] = policy.values[a] + policy.alpha * (policy.values[b] - policy.values[a])
        end
    end

    policy.exploiting_moves = [[]]
end


# todo: return value difference? For convergence test.
 # function train_game!(model_me::Model, model_opponent::Model, alpha::Float64, exploration_prob::Float64)
 #     @assert model_me.player == me
 #     @assert model_opponent.player == opponent
 #     exploiting_moves_me::Array{Array{Int64, 1}, 1} = [[]]
 #     exploiting_moves_opponent::Array{Array{Int64, 1}, 1} = [[]]
 #     board = Board()
 #     current_player = opponent
 #     while true
 #         winner = get_winner(board)
 #         if winner != nobody
 #             break
 #         end
 #         if is_board_full(board)
 #             break
 #         end
 # 
 #         if current_player == opponent
 #             board = learner_move!(model_opponent, board, current_player, exploiting_moves_opponent, exploration_prob)
 #             current_player = me
 #         else
 #             board = learner_move!(model_me, board, current_player, exploiting_moves_me, exploration_prob)
 #             current_player = opponent
 #         end
 #     end
 # 
 #     last_index = index_from_board(board)
 #     if exploiting_moves_me[end][end] != last_index
 #         push!(exploiting_moves_me[end], last_index)
 #     end
 #     if exploiting_moves_opponent[end][end] != last_index
 #         push!(exploiting_moves_opponent[end], last_index)
 #     end
 # 
 #     for moves in exploiting_moves_me
 #         update_values!(model_me, alpha, moves)
 #     end
 # 
 #     for moves in exploiting_moves_opponent
 #         update_values!(model_opponent, alpha, moves)
 #     end
 # 
 # end



function print_move(state_ind)
    print(state_ind)
    print(": \n")
    pprint_state(state_ind)
    print("\n\n")
end


function play_game!(policy_me::Policy, policy_opponent::Policy)
    @assert policy_me.player == me
    @assert policy_opponent.player == opponent
    board = Board()
    current_player = opponent
    winner = nobody
    while true
        winner = get_winner(board)
        if winner != nobody
            break
        end
        if is_board_full(board)
            break
        end

        if current_player == opponent
            board = move!(policy_opponent, board)
            current_player = me
        else
            board = move!(policy_me, board)
            current_player = opponent
        end
    end

    last_index = index_from_board(board)
    update!(policy_me, last_index)
    update!(policy_opponent, last_index)
    return winner
end


function train!(policy_me::Policy, policy_opponent::Policy, num_games::Int)
    # srand(345)  # random seed
    for i in 1:num_games
        play_game!(policy_me, policy_opponent)
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


function success_rate(policy_me::Policy, policy_opponent::Policy, num_games::Int64)

    num_wins = 0
    num_draws = 0
    for i in 1:num_games
        winner = play_game!(policy_me, policy_opponent)
        if winner == me
            num_wins += 1
        elseif winner == nobody
            num_draws += 1
        end
    end

    return Stats(num_wins / num_games, num_draws / num_games, (num_games - num_wins - num_draws) / num_games)
end

end  # module



import JSON
using .TicTacToe

"""
- main function: computes a success metric
- trains once over 300,000 games & then plays another 1000 games and outputs the success rate
"""
function main()
    policy_me = LearnerPolicy(me, 0.3, 0.3, true)
    policy_opponent = LearnerPolicy(opponent, 0.3, 0.3, true)
    
    train!(policy_me, policy_opponent, 3000)
    println("Training done")

    println("Writing output to file")
    fh = open("values.json", "w")
    write(fh, JSON.json(policy_me.values))
    close(fh)
    println("Done writing")

    policy_me.update = false
    policy_opponent = PerfectPolicy(opponent)

    for i in 1:10
        println("Test run $i of 10")
        print(success_rate(policy_me, policy_opponent, 1000))
    end

end

main()
