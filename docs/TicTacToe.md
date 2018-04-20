# Debugging TicTacToe

- How to implement so that it converges and is playable?


## Visualisation / Debugging

How do we visualise how these weights are changing?

Propagation should be successful: at the moment it doesn't seem to be.

Questions we can ask about the weights:

- what are the values they take, and with which frequency?
- do board configurations close to winning / losing have a high / low desirability?


## Refactor

The refactor should (at least) allow me to ask these questions easily.

- easy to find the value of a given state by just inputting the array.

Also want to train easily: abstract away the model

model = states with values

and then a player, which takes as input a board configuration and outputs the next board configuration

- random player
-

Would like to abstract away certain key functionalities.

E.g. player, opponent, state.


## Experiments

- propagate both moves
Computes the probability of *winning* in a certain state. Or alternatively
the probability of you winning given that the opponent is in that state.

*I am assuming that the opponent is following a certain strategy*.
