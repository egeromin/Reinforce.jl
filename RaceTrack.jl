module RaceTrack



export generate_episode, load_racetrack, QValues


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
    track = map(TrackPoint, racetrack)
    Track(reshape(track, max_grid_size))
end


abstract type TerminalState end

struct RaceTrackState
    position::Tuple{Int,Int}
    velocity::Tuple{Int,Int}
end  
# to simplify the problem, we only keep track of the position
# when computing the Q-values


const RaceTrackFullState = Union{RaceTrackState, Type{TerminalState}}


struct Action  # action with x-acceleration and y-acceleration
    xacc::Int
    yacc::Int
end


struct QValues
    q::Array{Float64, 4}

    QValues() = new(init_qvalues())
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
            println(pos)
            return random_start()  
            # might happen in case I go down from the start line
            # should not happen otherwise
        end

        if track[pos...] == green
            println("here")
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

    episode = []
    state = random_start(track)
    push!(episode, state)

    # while state != TerminalState
    for i in 1:max_episode_length
        action = epsilon_greedy(eps, q, state)
        state = next_state(track, state, action)
        push!(episode, state)

        if state == TerminalState
            break
        end
    end

    return episode

end


end

