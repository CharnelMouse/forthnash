{
Simple Forth script for finding a Nash equilibrium for a two-player zero-sum game.
We begin with assuming a 2x2 game, with integer values.

Simple solution (implemented):
- Check for a saddle point.
- If there isn't one, a row/col's weight is the absolute difference between
  the elements in the other row/col.

Currently implementing the simplex method, with the simple tableau format from Williams.
Currently no consideration of number value wrap.
}

\ need to add way to use own payoff matrix instead of a hard-coded one

\ 2x2 games
\ 2 CONSTANT #ROW 2 CONSTANT #COL
\ saddle
\ CREATE GAME 1 , 2 , 3 , 4 ,
\ no saddle
\ CREATE GAME 3 , 6 , 5 , 4 ,

\ 3x3 game
\ 3 CONSTANT #ROW 3 CONSTANT #COL
\ saddle
\ CREATE GAME 1 , 2 , 3 , 4 , 5 , 6 , 7 , 8 , 9 ,
\ no saddle
\ CREATE GAME 1 , 2 , 7 , 6 , 5 , 4 , 3 , 8 , 9 ,

\ 4x4 game to test integer runover. ATM works, but leaves numbers on the stack for last 3 pivots
4 CONSTANT #ROW 4 CONSTANT #COL
CREATE GAME
36 , 12 , 29 , 17 ,
0 , 24 , 29 , 17 ,
45 , 21 , 38 , 14 ,
9 , 33 , 2 , 26 ,

\ needed for simple 2x2 solution method, or at least for checking for saddle points
CREATE ROWMINS #ROW ALLOT
CREATE COLMAXS #COL ALLOT

: FETCH CELLS GAME + @ ;
: TIND SWAP #COL * + ;
: TABLE-FETCH SWAP #COL * + FETCH ;

\ Williams simplex variables
\ later will need to ensure elements are positive integers first
: AFILL 0 DO DUP , LOOP DROP ; \ ALLOT + FILL
: SEQ   0 DO I   , LOOP ;
CREATE A #ROW #COL * CELLS ALLOT
GAME A #ROW #COL * CELLS MOVE
CREATE B 1 #ROW AFILL
CREATE C -1 #COL AFILL
VARIABLE V \ Might not need, used strat values will add to this for solved schema
CREATE D 1 ,
\ [1, #ROW] for occupied, 0 for empty
CREATE P1-FREE #ROW SEQ
CREATE P1-BASE -1 #COL AFILL
\ [1, #COL] for occupied, 0 for empty
CREATE P2-FREE #COL SEQ
CREATE P2-BASE -1 #ROW AFILL

\ getters/setters
: A@ CELLS A + @ ;
: A! CELLS A + ! ;
: B@ CELLS B + @ ;
: B! CELLS B + ! ;
: C@ CELLS C + @ ;
: C! CELLS C + ! ;
: P1F@ CELLS P1-FREE + @ ;
: P2F@ CELLS P2-FREE + @ ;
: P1B@ CELLS P1-BASE + @ ;
: P2B@ CELLS P2-BASE + @ ;

\ for manual testing
: .RP DUP 0< IF DROP 1+ SPACES ELSE SWAP .R SPACE THEN ;
: .ARRAY 0 DO DUP I CELLS + @ . LOOP DROP ;
: .RARRAY 0 DO 2DUP I CELLS + @ SWAP .R SPACE LOOP 2DROP ;
: .RPARRAY ( +n addr n ) 0 DO 2DUP I CELLS + @ .RP LOOP 2DROP ;
: .MATRIX-ROW ( addr width row -- ) OVER * CELLS ROT + SWAP .ARRAY ;
: .MATRIX ( addr width height -- ) 0 DO CR 2DUP I .MATRIX-ROW LOOP 2DROP ;
: .GAME GAME #COL #ROW .MATRIX ;
: .ROWMINS ROWMINS #ROW .ARRAY ;
: .COLMAXS COLMAXS #COL .ARRAY ;
: .| [CHAR] | EMIT SPACE ;
: .P2-FREES ( +n ) P2-FREE #COL .RPARRAY ;
: .P1-FREE ( +n r ) P1F@ .RP ;
: .P2-BASE ( +n r ) P2B@ .RP ;
: .MAIN-ROW ( +n r ) 2DUP #COL * CELLS A + #COL .RARRAY .| CELLS B + @ SWAP .R ;
: .MAIN-ROWS ( +n ) #ROW 0 DO DUP I 2DUP .P1-FREE 2DUP .MAIN-ROW SPACE .P2-BASE CR LOOP DROP ;
: .C-ROW C #COL .RARRAY ;
: .V V @ SWAP .R ;
: .-N 0 DO [CHAR] - EMIT LOOP ;
: .LINE ( +n ) 1+ DUP #COL * .-N [CHAR] + EMIT .-N ;
: .P1-BASES P1-BASE #COL .RPARRAY ;
: .D D @ . ;
: .SCHEMA ( +n )
   CR DUP 1+ SPACES DUP .P2-FREES
   CR DUP .MAIN-ROWS
      DUP 1+ SPACES DUP .LINE
   CR DUP 1+ SPACES DUP .C-ROW .| DUP .V  ."  D = " .D
   CR DUP 1+ SPACES .P1-BASES
   CR ;

\ rowmin and colmax calculation
\ calculate rowmins and colmaxes
: SET-ROWMIN CELLS ROWMINS + ! ;
: SET-COLMAX CELLS COLMAXS + ! ;
: GET-ROWMIN CELLS ROWMINS + @ ;
: GET-COLMAX CELLS COLMAXS + @ ;
: UPDATE-COLMAX TUCK GET-COLMAX MAX SWAP SET-COLMAX ;
\ top row elements set initial colmaxs, other-row elements roll them
: TOP-LEFT-VALUE    (         -- el ) 0    FETCH        DUP 0   SET-COLMAX ;
: TOP-ROW-VALUE     (     col -- el ) DUP  FETCH        DUP ROT SET-COLMAX ;
: NONTOP-LEFT-VALUE ( row     -- el ) 0    TABLE-FETCH  DUP 0   UPDATE-COLMAX ;
: NONTOP-ROW-VALUE  ( row col -- el ) TUCK TABLE-FETCH  DUP ROT UPDATE-COLMAX ;
\ after each non-left element, roll the rowmin
: TOP-NONLEFT-ROW    ( el     -- el ) #COL 1 DO     I TOP-ROW-VALUE        MIN      LOOP ;
: NONTOP-NONLEFT-ROW ( el row -- el ) #COL 1 DO DUP I NONTOP-ROW-VALUE ROT MIN SWAP LOOP DROP ;
\
: TOP-ROW        TOP-LEFT-VALUE          TOP-NONLEFT-ROW      0    SET-ROWMIN ;
: NONTOP-ROW DUP NONTOP-LEFT-VALUE  OVER NONTOP-NONLEFT-ROW   SWAP SET-ROWMIN ;
\
: OTHER-ROWS #ROW 1 ?DO I NONTOP-ROW LOOP ;
: FIND-EXTREMES TOP-ROW OTHER-ROWS ;

\ printing mixed strategies (2x2 matrices only)
: .. DUP 0< (D.) TYPE ; \ like ., but without the ending space
: ROW-ADIFF DUP 0 TABLE-FETCH   SWAP 1 TABLE-FETCH  - ABS ;
: COL-ADIFF 0 OVER TABLE-FETCH  1 ROT TABLE-FETCH   - ABS ;
: ..ROW-RATIO 1 ROW-ADIFF .. ." :" 0 ROW-ADIFF .. ;
: ..COL-RATIO 1 COL-ADIFF .. ." :" 0 COL-ADIFF .. ;

\ these could be stored at end of CALCULATE-EXTREMES instead,
\ if I find another place to use them
: ROW-MINMAX 0 GET-ROWMIN #ROW 1 ?DO I GET-ROWMIN MAX LOOP ;
: COL-MAXMIN 0 GET-COLMAX #COL 1 ?DO I GET-COLMAX MIN LOOP ;

\ Simplex algorithm variables
VARIABLE PIVOT-COL
VARIABLE PIVOT-COLVAL
VARIABLE PIVOT-ROW
VARIABLE PIVOT-ROWVAL
VARIABLE PIVOT-VAL

CREATE P1-STRAT #ROW CELLS ALLOT
CREATE P2-STRAT #COL CELLS ALLOT

: P1S@ CELLS P1-STRAT + @ ;
: P2S@ CELLS P2-STRAT + @ ;
: P1S! CELLS P1-STRAT + ! ;
: P2S! CELLS P2-STRAT + ! ;

: .PC PIVOT-COL @ . ;
: .PCV PIVOT-COLVAL @ . ;
: .PR PIVOT-ROW @ . ;
: .PRV PIVOT-ROWVAL @ . ;
: .PV PIVOT-VAL @ . ;

\ Simplex algorithm
\ Chooses col based on smallest value, rather than checking -rc/p values

: UNSOLVED? FALSE #COL 0 DO DROP I C@ 0< IF TRUE LEAVE ELSE FALSE THEN LOOP ;

: INIT-COL 0 C @ ;
: ROLL-COL TUCK C@ 2DUP > IF ROT 2NIP SWAP ELSE DROP NIP THEN ;
: COL INIT-COL #COL 1 ?DO I ROLL-COL LOOP PIVOT-COLVAL ! PIVOT-COL ! ;

: INIT-ROW -1 PIVOT-ROW ! 0 PIVOT-VAL ! 1 PIVOT-ROWVAL ! ;
: ROW-VALS ( n -- rv av ) DUP B@ SWAP PIVOT-COL @ TIND A@ ;
: FP< ( n1 d1 n2 d2 ) -ROT * -ROT * > ; \ n1/d1 < n2/d2 ? for d1,d2 positive
: LOWER-RAT? ( r2 a2 ) PIVOT-ROWVAL @ PIVOT-VAL @ FP< ;
: REPLACE-ROW PIVOT-VAL ! PIVOT-ROWVAL ! PIVOT-ROW ! ;
: LOWER-RAT 2DUP LOWER-RAT? IF REPLACE-ROW ELSE 3DROP THEN ;
: ROLL-ROW DUP ROW-VALS DUP 0< IF 3DROP ELSE LOWER-RAT THEN ;
: ROW INIT-ROW #ROW 0 DO I ROLL-ROW LOOP ;

: GO-V V @ PIVOT-VAL @ * PIVOT-ROWVAL @ PIVOT-COLVAL @ * - D @ / V ! ;

: GO-B-EL DUP DUP B@ PIVOT-VAL @ * SWAP PIVOT-COL @ TIND A@ PIVOT-ROWVAL @ * - D @ / SWAP B! ;
: GO-B-ROW DUP PIVOT-ROW @ <> IF GO-B-EL ELSE DROP THEN ;
: GO-B #ROW 0 DO I GO-B-ROW LOOP ;

: GO-C-EL DUP DUP C@ PIVOT-VAL @ * SWAP PIVOT-ROW @ SWAP TIND A@ PIVOT-COLVAL @ * - D @ / SWAP C! ;
: GO-C-COL DUP PIVOT-COL @ <> IF GO-C-EL ELSE DROP THEN ;
: GO-C #COL 0 DO I GO-C-COL LOOP ;

: A@P* A@ PIVOT-VAL @ * ;
: RV ( c -- rv ) PIVOT-ROW @ SWAP TIND A@ ;
: CV ( r -- cv ) PIVOT-COL @      TIND A@ ;
: NON-ORTHOG-VALUE ( r c -- n ) 2DUP TIND A@P* -ROT RV SWAP CV * - D @ / ;
: NON-ORTHOG-EL ( r c ) 2DUP NON-ORTHOG-VALUE -ROT TIND A! ;
: NON-ORTHOG-COL ( r c ) DUP PIVOT-COL @ = IF 2DROP ELSE NON-ORTHOG-EL THEN ;
: NON-ORTHOG-ROW ( r ) DUP PIVOT-ROW @ <> IF #COL 0 DO DUP I NON-ORTHOG-COL LOOP THEN DROP ;
: NON-ORTHOG #ROW 0 DO I NON-ORTHOG-ROW LOOP ;

: NEG! ( addr -- ) DUP @ -1 * SWAP ! ;
: NEG-A ( pcol prow row --) TUCK <> IF SWAP TIND CELLS A + NEG! ELSE 2DROP THEN ; 
: NEG-C CELLS C + NEG! ;
: NEG-COL PIVOT-COL @ DUP PIVOT-ROW @ #ROW 0 DO 2DUP I NEG-A LOOP 2DROP NEG-C ;

: SWAP-SELF D @ PIVOT-ROW @ PIVOT-COL @ TIND A! PIVOT-VAL @ D ! ; \ less ops than using MEM-SWAP

: MEM-SWAP 2DUP @ SWAP @ ROT ! SWAP ! ;
: SWAP-P1 PIVOT-ROW @ CELLS P1-FREE + PIVOT-COL @ CELLS P1-BASE + MEM-SWAP ;
: SWAP-P2 PIVOT-ROW @ CELLS P2-BASE + PIVOT-COL @ CELLS P2-FREE + MEM-SWAP ;

: GO GO-V GO-B GO-C NON-ORTHOG NEG-COL SWAP-SELF SWAP-P1 SWAP-P2 ;

: PIVOT COL ROW GO ;
: SIMPLEX BEGIN UNSOLVED? WHILE PIVOT REPEAT ;

: SADDLE? ROW-MINMAX DUP COL-MAXMIN = ;

\ Strategies from saddle point solutions
: ISP1 DUP ROWMINS + @ ROT <> IF 0 ELSE 1 THEN SWAP P1-STRAT + ! ;
: ISP2 DUP COLMAXS + @ ROT <> IF 0 ELSE 1 THEN SWAP P2-STRAT + ! ;
: SP1 ROW-MINMAX #ROW 0 DO DUP I CELLS ISP1 LOOP DROP ;
: SP2 COL-MAXMIN #COL 0 DO DUP I CELLS ISP2 LOOP DROP ;
: SADDLE V ! SP1 SP2 ;

\ Strategies from solved schema
: ISM1F     P1F@ DUP 0< IF DROP  ELSE 0       SWAP P1S! THEN ;
: ISM2F     P2F@ DUP 0< IF DROP  ELSE 0       SWAP P2S! THEN ;
: ISM1B DUP P1B@ DUP 0< IF 2DROP ELSE SWAP C@ SWAP P1S! THEN ;
: ISM2B DUP P2B@ DUP 0< IF 2DROP ELSE SWAP B@ SWAP P2S! THEN ;
: SM1F #ROW 0 DO I ISM1F LOOP ;
: SM1B #COL 0 DO I ISM1B LOOP ;
: SM2F #COL 0 DO I ISM2F LOOP ;
: SM2B #ROW 0 DO I ISM2B LOOP ;
: SM1 SM1F SM1B ;
: SM2 SM2F SM2B ;
: SM SM1 SM2 ;

: NASH FIND-EXTREMES SADDLE? IF SADDLE ." Saddle" ELSE DROP SIMPLEX SM ." Mixed" THEN ;

: GCD 2DUP < IF SWAP THEN DUP 0= IF DROP ELSE BEGIN TUCK MOD DUP 0= UNTIL DROP THEN ;
: GCD-ROLL CELLS + @ DUP 0= IF DROP ELSE GCD THEN ;
: GCD-VEC ( addr len -- n ) OVER @ SWAP 1 ?DO OVER I GCD-ROLL LOOP NIP ;

: .P1 ." P1: " P1-STRAT #ROW GCD-VEC P1-STRAT @ OVER / .. #ROW 1 ?DO ." :" I P1S@ OVER / .. LOOP DROP ;
: .P2 ." P2: " P2-STRAT #COL GCD-VEC P2-STRAT @ OVER / .. #COL 1 ?DO ." :" I P2S@ OVER / .. LOOP DROP ;
: .VALUE ." Value: " V @ D @ 2DUP GCD TUCK / .. / DUP 1 = IF DROP ELSE ." /" . THEN ;
: .NASH CR .P1 CR .P2 CR .VALUE ; \ needs to indicate when strategy ratios are giving saddle points
