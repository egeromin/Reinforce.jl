module RaceTrack



export generate_episode, load_racetrack, monte_carlo_control, save_episode, QValues, main


"""
A point on the grid is either outside the track, 
inside the track, a starting point or an ending
point

black = boundary
green = beginning
red = ending
white = filling
"""
@enum TrackPoint black green red white


max_grid_size = (50, 50)
grid_bound = max_grid_size[1]

max_episode_length = 200


# we need to define the grid for this problem
# and the easiest way to do so is to draw it
# internally, we define this as a 2darray of bools
# with true for any eleme

# final output: pick a starting position and generate
# a bunch of episodes. This can be as a sequence of 
# images. Then convert to GIF using imagemagick.


# should be able to define the racetrack somewhere
# and then import it into julia


function get_start_positions(track::Array{TrackPoint})
    grid = [(i, j) for i in 1:max_grid_size[1]
            for j in 1:max_grid_size[2]]

    filter(pos -> track[pos...] == red, grid)
end


struct Track
    t::Array{TrackPoint}
    start_positions::Array{Tuple{Int,Int}}

    Track(t) = new(t, get_start_positions(t))
end


function Base.getindex(t::Track, inds::Int...)
    t.t[inds...]
end



"""
Load the binary racetrack data
"""
function load_racetrack(path::String)
    fh = open(path, "r")
    # use read with the length of bytes to be read
    racetrack = read(fh, reduce(*, max_grid_size))
    close(fh)
    track = map(TrackPoint, racetrack)
    Track(reshape(track, max_grid_size))
end


@enum TerminalStateType TerminalState


struct RaceTrackState
    position::Tuple{Int,Int}
    velocity::Tuple{Int,Int}
end  
# to simplify the problem, we only keep track of the position
# when computing the Q-values


const RaceTrackFullState = Union{RaceTrackState, TerminalStateType}


struct Action  # action with x-acceleration and y-acceleration
    xacc::Int
    yacc::Int
end

@enum NoActionType NoAction
# no action. Used to represent the action following the last state


const FullAction = Union{Action, NoActionType}


const Episode = Array{Tuple{RaceTrackFullState, FullAction}}
# store both state and action in the episode


struct QValues
    q::Array{Float64, 4}

    QValues() = new(init_qvalues())
    QValues(qv::Array{Float64, 4}) = new(qv)
end



function init_returns() 

    function make_empty(i)
        Array{Float64, 1}([])
    end

    map(make_empty, init_qvalues())
end


struct StateActionReturns
    r::Array{Array{Float64}}

    StateActionReturns() = new(init_returns())
end



"""
Generate a table of empty qvalues for each state-action pair
"""
function init_qvalues()
    zeros(Float64, tuple(max_grid_size..., (3, 3)...))  # tuple concatenation
end


function Base.getindex(q::QValues, state::RaceTrackState, action::Action)
    pos = tuple(state.position..., action.xacc+2, action.yacc+2)
    q.q[pos...]
end


function Base.setindex(q::QValues, val::Float64,
                       state::RaceTrackState, action::Action)
    pos = tuple(state.position..., action.xacc+2, action.yacc+2)
    q.q[pos...] = val
end


function Base.getindex(r::StateActionReturns, state::RaceTrackState, action::Action)
    pos = tuple(state.position..., action.xacc+2, action.yacc+2)
    r.r[pos...]
end

# 
# function Base.getindex(r::StateActionReturns, state::RaceTrackState, action::Action)
#     pos = tuple(state.position..., action.xacc+2, action.yacc+2)
#     r.r[pos...]
# end
# setindex not required


function update_velocity(state::RaceTrackState, action::Action)
    new_velocity = collect(state.velocity) + [action.xacc, action.yacc]

    # now cap the velocity to be within bounds
    new_velocity = map(a -> min(5, a), new_velocity)
    map(a -> max(-5, a), new_velocity)
end
    


"""
Calculate the next state, given the current state 
and given the current action

Also calculates whether or not I've reached a border
and so if I need to start from scratch
"""
function next_state(track::Track, state::RaceTrackState, action::Action)

    new_velocity = update_velocity(state, action)
    current_position = Array{Float64}(collect(state.position))
    
    pos = nothing  # define pos here, for scoping

    for i in 1:5
        current_position .+= (0.2 .* new_velocity)
        # 0.2 is the minimal increment.

        pos = map(Int ∘ floor, current_position)  
        # sanitized position
        # `∘` is function composition!!

        if maximum(pos) > grid_bound || minimum(pos) < 0
            # println(pos)
            return random_start()  
            # might happen in case I go down from the start line
            # should not happen otherwise
        end

        if track[pos...] == green
            # println("here")
            return TerminalState
        elseif track[pos...] in (black, red)
            return random_start(track)
        end

    end

    RaceTrackState(tuple(pos...), tuple(new_velocity...))

end



"""
Select a state at a random point along the starting line
"""
function random_start(track::Track)
    RaceTrackState(rand(track.start_positions),
                   (0, 0))
end


"""
Epsilon-greedy policy given the current Q-values
at the current state
"""
function epsilon_greedy(eps::Float64, q::QValues, state::RaceTrackState)
    actions = [Action(i, j) for i in -1:1 for j in -1:1]
    state_action_values = map(a -> q[state, a], actions)
    best_action_index = argmax(state_action_values)
    # if there's multiple actions that are optimal, then policy
    # improvement happens irrespective of the one we choose
    # so may as well choose the first, using argmax
    best_action = actions[best_action_index]
    other_actions = vcat(actions[1:best_action_index-1],
                         actions[best_action_index+1:end])

    exploration_cutoff = 1 - eps + eps / length(actions)

    if rand(Float64) > exploration_cutoff
        rand(other_actions)
    else
        best_action
    end

end



"""
Generate an episode given a track.
"""
function generate_episode(track::Track, eps::Float64, q::QValues)

    episode::Episode = []
    state = random_start(track)

    # while state != TerminalState

    for i in 1:max_episode_length
        action = epsilon_greedy(eps, q, state)
        push!(episode, (state, action))

        state = next_state(track, state, action)

        if state == TerminalState
            break
        end
    end

    push!(episode, (state, NoAction))

    return episode

end


function update_state_returns!(episode::Episode, eps::Float64,
                               r::StateActionReturns, 
                               first_visit::Bool=true)

    current_return::Float64 = 0
    state, _ = episode[end]

    for i in length(episode)-1:-1:1
        current_return += -1
        state, action = episode[i]  

        if !((state, action) in episode[1:i-1]) || (!first_visit)
            push!(r[state, action], current_return)
        end
    end

    QValues(map(mean, r.r))
end


"""
On-policy monte-carlo control
"""
function monte_carlo_control(track::Track, num_episodes::Int, eps::Float64)

    qval = QValues()
    returns = StateActionReturns()

    episode_lengths = []

    for i in 1:num_episodes
        episode = generate_episode(track, eps, qval)
        @assert isa(episode, Episode)
        qval = update_state_returns!(episode, eps, returns)
        push!(episode_lengths, length(episode))

        if i % 1000 == 0
            println(@sprintf "Done %i of %i; episode length %i" i num_episodes length(episode))
        end
    end

    return qval, episode_lengths
end


"""
Save the path taken during an episode to file
"""
function save_episode(path::String, episode::Episode)
    if episode[end][1] == TerminalState
        episode = episode[1:end-1]
    end
    positions = reduce((acc, s) -> [s[1].position..., acc...],
                       [], episode)
    
    fh = open(path, "w")
    write(fh, Array{UInt8}(positions))
    close(fh)
end



"""
main function
"""

function main(path_racetrack::String, path_episode::String,
              num_episodes::Int, eps::Float64)

    track = load_racetrack(path_racetrack)
    qval, _ = monte_carlo_control(track, num_episodes, eps)

    episode = generate_episode(track, 0.0, qval)
    save_episode(path_episode, episode)

end

end

