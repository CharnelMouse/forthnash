## Nash solver for two-player zero-sum games

This takes zero-sum games in matrix form, and returns the Nash equilibrium, in the form

P1: a1:a2:...\
P2: b1:b2:...\
Value: V

where ax and bx give the players' mixed strategies, in lowest-possible integers, and V is the game value. If the game has saddle points, the strategy ratio elements are 1 for saddle point strategies, and 0 elsewhere.

Useful words:

- .GAME ( -- ) prints the game matrix. Currently with no formatting to align the rows.
- .SCHEMA (n -- ) displays the current state of the schema used for the solution method, where n is the number of spaces reserved for each element to keep them aligned. For proper alignment, this should be at least as large as the length of the longest current schema element.
- NASH ( -- ) solves the given game. First, it checks whether the game has saddle points. If so, it sets the player strategies as an even mixture of the saddle point strategies. Otherwise, it uses a simplified form of the Simplex method (details below).
- .NASH prints the solution. Must call NASH first.
- .ROWMINS and .COLMAXS return the row minima and column maxima, for comparison to claimed saddle points. Must call NASH first.

To implement:

- Reading the game from a file, instead of hard-coded values.
- Finding more equilibria when a game has more than one.
- Scaling a game to be positive and integral before solving it, and converting back at solution presentation time.

### Explanation of the used version of the simplex method

#### Linear program

Suppose we have a game described by n x m matrix **G**, describing the payoff to player 1. Player 1 chooses a row and wants to maximise the payoff, and player 2 chooses a column and wants to minimise the payoff. Their mixed strategies are described by an n-length column vector **p** and an m-length column vector **q**, respectively, where the elements of each are non-negative and sum to one.

Player 2 can be said to be solving the problem

max **1**'**v** where **v** ⪰ **0**, **Gv** ⪯ **1**,

or

min -**1**'**v** where **v** ⪰ **0**, **Gv** ⪯ **1**,

where **q** = **v**/(**1**'**v**) and V = 1/(**1**'**v**). Player 1 can be said to be solving the dual problem.

If every element of **G** is positive, there is at least one such solution, and so the game has at least one Nash equilibrium.

#### Usual simplex method

The classical tableau for the linear program

min -**c**'**x** where **x** ⪰ **0**, **Ax** = **b**,

where **x**, **A** etc. include slack variables, is

||||
|:-:|:-:|:-:|
|  d  |-**c**'|  z  |
|**0**| **A** |**b**|,

where z is initially equal to zero, and d is initially equal to one. These elements track the following:

||||
|:-:|:-:|:-:|
|scaling factor|full derivatives WRT objective function|objective function|
|nothing|partial derviatives WRT constraints|constraint values|.

When the problem is solved, the top-middle section contains the marginal utilities for increasing the constaint values, including the values in **u**, and the bottom-right section contains the values of used variables, including the values in **v**.

Pivot operations are done in the following way:

1. Choose a pivot column l and a pivot row w, such that their shared element is in **A**. This must be chosen such that the element of **c** in l is negative, and that the elementwise division of **b** and the elements of **A** in l has its minimum value on row w. The column corresponds to a currently-unused (*free*) variable to increase, where increasing it decreases the objective function, after accounting for changes in used (*base*) variables to satisfy the constraints. As we increase the chosen unused variable, we must reduce the used variables to satisfy the constraints. Determine which one will reach zero first, leaving the chosen free variable as the new base variable for that constraint. If there's a tie, choose one.
2. Change the element values, according to the choices of l and w. Let t = **A**[w,l] be the pivot element value. Set the other elements of the pivot column to zero; keep elements in the pivot row the same; change other elements to the 2 x 2 minor determinant, using the element, the pivot, and the two elements that together form a square, as the pivot's diagonal minus the other diagonal.

In step 1, l is usually chosen first, as the column with the smallest (greatest-magnitiude) negative value of **c**.

In step 2, we can alternatively divide through by t afterwards, keeping the scaling factor equal to 1. This is more useful for working out how the element value changes relate to solving the linear program. We stick to the version where we don't divide by t, because if the linear program only contains integers it keeps everything in terms of integers. However, this results in the element values becoming very large after a few iterations.

#### Modified Tucker tableau (Williams)

Instead of the usual simplex tableau described above, we use the modified version of the Tucker tableau, described in later versions of The Compleat Strategyst by JD Williams (1966 onwards). This modified tableau is

|||
|:-:|:-:|
| **A** |**b**|
|-**c**'|**z**|,

where **A** only shows the partial derivatives for the current free variables. Instead of setting the other elements in the pivot column to zero, they are now multiplied by -1, which effectively replaces the old base variable's column with the new one's. Instead of tracking the base variables by looking for which columns form a permuted identity matrix, we track it with additional markers around the outside, which change position when their row/column is used as the pivot. Player 1's strategies start on the rows, and player 2's strategies start on the columns. A player 1 strategy is currently a base variable, i.e. used, if its label is on the columns, and similarly for player 2.

The above describes the usual Tucker tableau. Unlike the classical or Tucker tableaus, however, instead of using an ever-growing scaling factor, or dividing by the pivot value each time, we store the pivot value in a separate variable d, and divide by it during the next pivot operation.

The pivot operation now works as follows:

- The non-pivot elements on the pivot row stay the same.
- The non-pivot elements on the pivot column are multiplied by -1.
- Other elements are set equal to the 2 x 2 minor determinant, divided by d.
- The pivot value is swapped with d.

This keeps the element values relatively small, while still ensuring that everything is done in terms of integers.

For the Forth implementation, I don't track the pre-scaling objective value z, since **1**'**b** and **1**'**c** are both equal to it when solved, so we can just calculate it then. The value of the original game is then d/z. The base strategy labels are in the row/column of **b** or **c**, which contains their value in **u** or **v**, so we also get the mixed strategy for both players.

Note that, in Williams, the pivot row and column are determined at the same time: among all the columns with negative **c** element, we would choose the row and column that maximises **b**[w]**c**[l]/t, i.e. maximises the resulting increase of the objective function. I've stayed with the method of choosing the column and row separately, for ease of computation.
