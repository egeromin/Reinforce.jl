#=
 
Blackjack prediction using monte carlo methods. 

Code to estimate the value function for a fixed policy that sticks
only at 20 and 21
 
=#


module BlackJack

export monte_carlo_prediction, generate_episode


@enum Action stick hit


struct StateArray
    a::Array{Any, 1} 
end
# the used for the returns and values of each state in blackjack



struct BlackJackState
    current_sum::Int  # vals 12-21
    dealer_card::Int  # vals 1-10
    usable_ace::Bool
end

# const TerminalState = Bool  
abstract type TerminalState end
# a singleton to signal the terminal state
# the easiest way to define singletons in julia is by using a type
# which then has type Type{type}


const BlackJackFullState = Union{BlackJackState, Type{TerminalState}}
# 'full' state, to include the termination token


function index_from_state(state::BlackJackState)::Int
    state.usable_ace * 100 + (state.dealer_card - 1) * 10 + 
        state.current_sum - 12 + 1
end


const max_state_index = 200


@assert max_state_index == index_from_state(BlackJackState(21, 10, true))

"""
Get/Set an array indexed by `state`
"""
function Base.getindex(a::StateArray, state::BlackJackState)
    a.a[index_from_state(state)]
end

function Base.setindex!(a::StateArray, value, state::BlackJackState)
    a.a[index_from_state(state)] = value
end


"""Draw a card from the deck with replacement"""
function draw_card()
    card = rand(1:13)
    if 11 <= card <= 13
        card = 10  # face card
    end
    card  # return a 1 for the Ace.
end


function fixed_policy(state::BlackJackState)
    if state.current_sum >= 20
        stick
    else
        hit
    end
end


"""
Update the total point sum based on the next card
"""
function update_sum(next_card, current_sum, usable_ace)
    if next_card == 1 && current_sum <= 21 - 11
        next_usable_ace = true
        next_current_sum = current_sum + 11
    elseif current_sum + next_card > 21 && usable_ace
        next_current_sum = current_sum + next_card - 10
        next_usable_ace = false
    else
        next_usable_ace = usable_ace
        next_current_sum = current_sum + next_card
    end

    (next_current_sum, next_usable_ace)
end



"""
Next state in the case that I'm hitting
"""
function next_state_hit(state::BlackJackState)
    next_card = draw_card()

    current_sum, usable_ace = update_sum(next_card, state.current_sum,
                                         state.usable_ace)

    if current_sum > 21
        reward = -1
        nxt_state = TerminalState
    else
        reward = 0
        nxt_state = BlackJackState(current_sum, state.dealer_card, usable_ace)
    end

    (nxt_state, reward)
end


function dealer_turn(state::BlackJackState)
    dealer_sum = state.dealer_card
    usable_ace = state.dealer_card == 1
    if usable_ace
        dealer_sum = 11
    end

    while dealer_sum < 17
        dealer_next_card = draw_card()
        dealer_sum, usable_ace = update_sum(dealer_next_card,
                                            dealer_sum, usable_ace)
    end

    if dealer_sum > 21
        reward = 1
    elseif state.current_sum > dealer_sum
        reward = 1
    elseif state.current_sum == dealer_sum
        reward = 0
    else
        reward = -1
    end

    (TerminalState, reward) 
end


"""
Function next_state: compute the next state
"""
function next_state(state::BlackJackState, action::Action)
    if action == hit
        next_state_hit(state)
    else
        dealer_turn(state)
    end
end


function generate_episode()
    episode = []

    # draw 2 initial cards
    initial_sum, usable_ace = 0, false
    initial_sum, usable_ace = update_sum(draw_card(), initial_sum, usable_ace)
    initial_sum, usable_ace = update_sum(draw_card(), initial_sum, usable_ace)

    state = BlackJackState(initial_sum, draw_card(), usable_ace)
    reward = 0
    if state.current_sum > 11
        push!(episode, (state, reward))
    end

    if initial_sum == 21  # check for a 'natural'
        dealer_card = state.dealer_card
        if dealer_card == 1
            dealer_card = 11
        end
        next_card = draw_card()
        if next_card == 1
            next_card = 11
        end

        if dealer_card + next_card == 21
            reward = 0
        else
            reward = 1
        end

        state = TerminalState
        push!(episode, (state, reward))
    end 

    while state != TerminalState
        action = fixed_policy(state)
        state, reward = next_state(state, action)
        if state == TerminalState || state.current_sum > 11
            push!(episode, (state, reward))  
            # only estimate values for policies where a decision is to be made
        end
    end

    episode
end


# not blackjack specific
function update_state_returns!(episode, state_returns, first_visit::Bool=true)

    current_return::Float64 = 0

    episode_states = map(x -> x[1], episode)

    (state, reward) = episode[end]
    @assert state == TerminalState

    for i in length(episode)-1:-1:1
        current_return += reward
        (state, reward) = episode[i]  
        # this reward belongs to the
        # 'previous' state

        if !(state in episode_states[1:i-1]) || (!first_visit)
            try
                push!(state_returns[state], current_return)
            catch y
                println(state)
                throw(y)
            end
        end
    end
end


function monte_carlo_prediction(num_episodes)

    function make_empty(i)
        Array{Float64, 1}([])
    end

    state_returns = StateArray(map(make_empty, 1:max_state_index))

    for i in 1:num_episodes
        episode = generate_episode()
        update_state_returns!(episode, state_returns)
    end

    state_values = StateArray(map(mean, state_returns.a))

    return state_values
end


end
