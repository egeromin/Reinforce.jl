# Next Steps for TicTacToe

We got the success rate up to 0.98. Great!

Next steps to investigate:

- play itself: works better against the random player
- exploratory moves -- does then number of non-losses against random player increase?
- tweak alpha
- decrease alpha during training so as to satisfy "convergence criteria"

Right now:

- if playing against random player, get lower number of non-losses than against slightly clever player.
- but, much lower number of wins.

Update:

- with self-play, get much better results against the random player (0 losses)
- AND can win against the slightly clever player (0 losses)
- How does it perform against a perfect player?

Update:

- never loses against a perfect player: 100% draws.
