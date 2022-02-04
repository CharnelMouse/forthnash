{
Simple Forth script for finding a Nash equilibrium for a two-player zero-sum game.
Checks for saddle points first.
If none, uses simplex method, with the simple tableau format from Williams.
Currently no consideration of integer over/underflow.
To implement: reading games from file, allowing continuation if multiple equilibria.
}

\ data structures

: AFILL 0 DO DUP , LOOP DROP ;
: ARRAY     (     len ) CREATE CELLS ALLOT DOES> SWAP CELLS + ;
: REP-ARRAY ( val len ) CREATE AFILL       DOES> SWAP CELLS + ;
: TOP 0 ;

: MATRIX ( nrow ncol -- )
  CREATE DUP , * CELLS ALLOT
  DOES> ( col row -- addr ) TUCK @ * 1+ ROT + CELLS + ;
: TL 0 0 ;
: & ( addr n -- addr ) OVER ! CELL+ ;

\ example games
\ need to add way to use own payoff matrix instead of a hard-coded one

\ 2x2 games
\ 2 CONSTANT #ROW 2 CONSTANT #COL
\ saddle
\ #ROW #COL MATRIX GAME
\ TL GAME
\ 1 & 2 &
\ 3 & 4 &
\ DROP
\ no saddle
\ #ROW #COL MATRIX GAME
\ TL GAME
\ 3 & 6 &
\ 5 & 4 &
\ DROP

\ 3x3 game
\ 3 CONSTANT #ROW 3 CONSTANT #COL
\ saddle
\ #ROW #COL MATRIX GAME
\ TL GAME
\ 1 & 2 & 3 &
\ 4 & 5 & 6 &
\ 7 & 8 & 9 &
\ DROP
\ no saddle
\ #ROW #COL MATRIX GAME
\ TL GAME
\ 1 & 2 & 7 &
\ 6 & 5 & 4 &
\ 3 & 8 & 9 &
\ DROP

\ 4x4 game
4 CONSTANT #ROW 4 CONSTANT #COL
#ROW #COL MATRIX GAME
TL GAME
36 & 12 & 29 & 17 &
 0 & 24 & 29 & 17 &
45 & 21 & 38 & 14 &
 9 & 33 &  2 & 26 &
DROP

\ needed for checking for saddle points

#ROW ARRAY ROWMINS
#COL ARRAY COLMAXS

\ Williams simplex variables
\ later will need to ensure elements are positive integers first

#ROW #COL MATRIX A
TL GAME TL A #ROW #COL * CELLS MOVE
 1    #ROW REP-ARRAY B
-1    #COL REP-ARRAY C

#ROW #COL + ARRAY LABELS \ Negative for P2
: P1-LABELS #ROW 1+ 1 DO DUP I      SWAP ! CELL+ LOOP ;
: P2-LABELS #COL 1+ 1 DO DUP I -1 * SWAP ! CELL+ LOOP ;
TOP LABELS P1-LABELS P2-LABELS DROP

VARIABLE V \ Might not need, used strat values will add to this for solved schema
CREATE D 1 ,

\ for manual testing
: .RP DUP 0< IF DROP 1+ SPACES ELSE      SWAP .R SPACE THEN ;
: .RN DUP 0> IF DROP 1+ SPACES ELSE -1 * SWAP .R SPACE THEN ;
: ?RP @ .RP ;
: ?RN @ .RN ;
: .| [CHAR] | EMIT SPACE ;

: .ARRAY   (    addr n )        0 DO    DUP  I CELLS + ?                     LOOP DROP  ;
: .RARRAY  ( +n addr n )        0 DO    2DUP I CELLS + @ SWAP .R SPACE       LOOP 2DROP ;
: .RPARRAY ( +n addr n )        0 DO    2DUP I CELLS + ?RP                   LOOP 2DROP ;
: .RNARRAY ( +n addr n )        0 DO    2DUP I CELLS + ?RN                   LOOP 2DROP ;
: .MATRIX-ROW ( addr width row -- ) OVER * CELLS ROT + SWAP .ARRAY ;
: .MATRIX ( addr width height ) 0 DO CR 2DUP I .MATRIX-ROW                   LOOP 2DROP ;
: .MAIN-ROW ( +n r ) 2DUP 0 SWAP A #COL .RARRAY .| 2DUP B @ SWAP .R SPACE LABELS ?RN ;
: .MAIN-ROWS ( +n )        #ROW 0 DO    DUP  I 2DUP LABELS ?RP .MAIN-ROW CR LOOP DROP  ;

: .GAME TL GAME #COL #ROW .MATRIX ;
: .ROWMINS TOP ROWMINS #ROW .ARRAY ;
: .COLMAXS TOP COLMAXS #COL .ARRAY ;
: .P2-FREES ( +n ) #ROW LABELS #COL .RNARRAY ;
: .C-ROW TOP C #COL .RARRAY ;
: .V V @ SWAP .R ;
: .-N 0 DO [CHAR] - EMIT LOOP ;
: .LINE ( +n ) 1+ DUP #COL * .-N [CHAR] + EMIT .-N ;
: .P1-BASES #ROW LABELS #COL .RPARRAY ;
: .D D ? ;
: .SCHEMA ( +n )
   CR DUP 1+ SPACES DUP .P2-FREES
   CR DUP .MAIN-ROWS
      DUP 1+ SPACES DUP .LINE
   CR DUP 1+ SPACES DUP .C-ROW .| DUP .V  ."  D = " .D
   CR DUP 1+ SPACES .P1-BASES
   CR ;

\ rowmin and colmax calculation
\ calculate rowmins and colmaxes
: UPDATE-COLMAX TUCK COLMAXS @ MAX SWAP COLMAXS ! ;
\ top row elements set initial colmaxs, other-row elements roll them
: TOP-LEFT-VALUE    (         -- el ) TL        GAME @ DUP 0   COLMAXS ! ;
: TOP-ROW-VALUE     (     col -- el ) DUP 0     GAME @ DUP ROT COLMAXS ! ;
: NONTOP-LEFT-VALUE ( row     -- el ) 0 SWAP    GAME @ DUP 0   UPDATE-COLMAX ;
: NONTOP-ROW-VALUE  ( row col -- el ) TUCK SWAP GAME @ DUP ROT UPDATE-COLMAX ;
\ after each non-left element, roll the rowmin
: TOP-NONLEFT-ROW    ( el     -- el ) #COL 1 DO     I TOP-ROW-VALUE        MIN      LOOP ;
: NONTOP-NONLEFT-ROW ( el row -- el ) #COL 1 DO DUP I NONTOP-ROW-VALUE ROT MIN SWAP LOOP DROP ;
: TOP-ROW        TOP-LEFT-VALUE         TOP-NONLEFT-ROW    0    ROWMINS ! ;
: NONTOP-ROW DUP NONTOP-LEFT-VALUE OVER NONTOP-NONLEFT-ROW SWAP ROWMINS ! ;
: OTHER-ROWS #ROW 1 ?DO I NONTOP-ROW LOOP ;
: FIND-EXTREMES TOP-ROW OTHER-ROWS ;

\ printing mixed strategies (2x2 matrices only)
: .. DUP 0< (D.) TYPE ; \ like ., but without the ending space
: ROW-ADIFF DUP 0  GAME @ SWAP 1 GAME @ - ABS ;
: COL-ADIFF 0 OVER GAME @ 1 ROT  GAME @ - ABS ;
: ..ROW-RATIO 1 ROW-ADIFF .. ." :" 0 ROW-ADIFF .. ;
: ..COL-RATIO 1 COL-ADIFF .. ." :" 0 COL-ADIFF .. ;

\ these could be stored at end of CALCULATE-EXTREMES instead,
\ if I find another place to use them
: ROW-MINMAX TOP ROWMINS @ #ROW 1 ?DO I ROWMINS @ MAX LOOP ;
: COL-MAXMIN TOP COLMAXS @ #COL 1 ?DO I COLMAXS @ MIN LOOP ;

\ Simplex algorithm variables
VARIABLE PIVOT-COL
VARIABLE PIVOT-COLVAL
VARIABLE PIVOT-ROW
VARIABLE PIVOT-ROWVAL
VARIABLE PIVOT-VAL
#ROW ARRAY P1-STRAT
#COL ARRAY P2-STRAT

: .PC  PIVOT-COL    ? ;
: .PCV PIVOT-COLVAL ? ;
: .PR  PIVOT-ROW    ? ;
: .PRV PIVOT-ROWVAL ? ;
: .PV  PIVOT-VAL    ? ;

\ Simplex algorithm
\ Chooses col based on smallest value, rather than checking -rc/p values

: UNSOLVED? FALSE #COL 0 DO DROP I C @ 0< IF TRUE LEAVE ELSE FALSE THEN LOOP ;

: INIT-COL TL C @ ;
: ROLL-COL TUCK C @ 2DUP > IF ROT 2NIP SWAP ELSE DROP NIP THEN ;
: COL INIT-COL #COL 1 ?DO I ROLL-COL LOOP PIVOT-COLVAL ! PIVOT-COL ! ;

: INIT-ROW -1 PIVOT-ROW ! 0 PIVOT-VAL ! 1 PIVOT-ROWVAL ! ;
: ROW-VALS ( n -- rv av ) DUP B @ SWAP PIVOT-COL @ SWAP A @ ;
: FP< ( n1 d1 n2 d2 ) -ROT * -ROT * > ; \ n1/d1 < n2/d2 ? for d1,d2 positive
: LOWER-RAT? ( r2 a2 ) PIVOT-ROWVAL @ PIVOT-VAL @ FP< ;
: REPLACE-ROW PIVOT-VAL ! PIVOT-ROWVAL ! PIVOT-ROW ! ;
: LOWER-RAT 2DUP LOWER-RAT? IF REPLACE-ROW ELSE 3DROP THEN ;
: ROLL-ROW DUP ROW-VALS DUP 0< IF 3DROP ELSE LOWER-RAT THEN ;
: ROW INIT-ROW #ROW 0 DO I ROLL-ROW LOOP ;

: GO-B-EL DUP DUP B @ PIVOT-VAL @ * SWAP PIVOT-COL @ SWAP A @ PIVOT-ROWVAL @ * - D @ / SWAP B ! ;
: GO-B-ROW DUP PIVOT-ROW @ <> IF GO-B-EL ELSE DROP THEN ;
: GO-B #ROW 0 DO I GO-B-ROW LOOP ;

: GO-C-EL DUP DUP C @ PIVOT-VAL @ * SWAP PIVOT-ROW @ A @ PIVOT-COLVAL @ * - D @ / SWAP C ! ;
: GO-C-COL DUP PIVOT-COL @ <> IF GO-C-EL ELSE DROP THEN ;
: GO-C #COL 0 DO I GO-C-COL LOOP ;

: RV ( c -- rv ) PIVOT-ROW @      A @ ;
: CV ( r -- cv ) PIVOT-COL @ SWAP A @ ;
: NON-ORTHOG-VALUE ( r c -- n ) 2DUP SWAP A @ PIVOT-VAL @ * -ROT RV SWAP CV * - D @ / ;
: NON-ORTHOG-EL ( r c ) 2DUP NON-ORTHOG-VALUE -ROT SWAP A ! ;
: NON-ORTHOG-COL ( r c ) DUP PIVOT-COL @ = IF 2DROP ELSE NON-ORTHOG-EL THEN ;
: NON-ORTHOG-ROW ( r ) DUP PIVOT-ROW @ <> IF #COL 0 DO DUP I NON-ORTHOG-COL LOOP THEN DROP ;
: NON-ORTHOG #ROW 0 DO I NON-ORTHOG-ROW LOOP ;

: NEG! ( addr -- ) DUP @ -1 * SWAP ! ;
: NEG-A ( pcol prow row --) TUCK <> IF A NEG! ELSE 2DROP THEN ; 
: NEG-C C NEG! ;
: NEG-COL PIVOT-COL @ DUP PIVOT-ROW @ #ROW 0 DO 2DUP I NEG-A LOOP 2DROP NEG-C ;

: SWAP-SELF D @ PIVOT-ROW @ PIVOT-COL @ SWAP A ! PIVOT-VAL @ D ! ; \ less ops than using MEM-SWAP

: MEM-SWAP 2DUP @ SWAP @ ROT ! SWAP ! ;
: SWAP-LABELS PIVOT-ROW @ LABELS #ROW PIVOT-COL @ + LABELS MEM-SWAP ;

: GO GO-B GO-C NON-ORTHOG NEG-COL SWAP-SELF SWAP-LABELS ;

: PIVOT COL ROW GO ;
: SIMPLEX BEGIN UNSOLVED? WHILE PIVOT REPEAT ;

: SADDLE? ROW-MINMAX DUP COL-MAXMIN = ;

\ Strategies from saddle point solutions
: SP1 #ROW 0 DO I 2DUP ROWMINS @ = 1 AND SWAP P1-STRAT ! LOOP DROP ;
: SP2 #COL 0 DO I 2DUP COLMAXS @ = 1 AND SWAP P2-STRAT ! LOOP DROP ;
: SADDLE ( saddle-value -- ) DUP D ! 1 V ! DUP SP1 SP2 ;

\ Strategies from solved schema
\ We set V here instead of on each pivot,
\ since at solution time it's equal to either
\ player's solution sum
: P1 1-     P1-STRAT ;
: P2 -1 XOR P2-STRAT ;
: TO-ZERO NIP 0 SWAP ;
: ROW-LABEL DUP 0< IF P2         ELSE P1 TO-ZERO THEN ! ;
: COL-LABEL DUP 0< IF P2 TO-ZERO ELSE P1         THEN ! ;
: ROW-LABELS #ROW 0 DO I DUP B @ SWAP        LABELS @ ROW-LABEL LOOP ;
: COL-LABELS #COL 0 DO I DUP C @ SWAP #ROW + LABELS @ COL-LABEL LOOP ;
: MIXED-STRATS ROW-LABELS COL-LABELS ;
: MIXED-VALUE 0 V ! #ROW 0 DO I P1-STRAT @ V +! LOOP ;
: MIXED SIMPLEX MIXED-STRATS MIXED-VALUE ;

: NASH FIND-EXTREMES SADDLE? IF SADDLE ." Saddle" ELSE DROP MIXED ." Mixed" THEN ;

: GCD 2DUP < IF SWAP THEN DUP 0= IF DROP ELSE BEGIN TUCK MOD DUP 0= UNTIL DROP THEN ;
: GCD-ROLL CELLS + @ DUP 0= IF DROP ELSE GCD THEN ;
: GCD-VEC ( addr len -- n ) OVER @ SWAP 1 ?DO OVER I GCD-ROLL LOOP NIP ;

: .P1 ." P1: " TOP P1-STRAT #ROW GCD-VEC TOP P1-STRAT @ OVER / .. #ROW 1 ?DO ." :" I P1-STRAT @ OVER / .. LOOP DROP ;
: .P2 ." P2: " TOP P2-STRAT #COL GCD-VEC TOP P2-STRAT @ OVER / .. #COL 1 ?DO ." :" I P2-STRAT @ OVER / .. LOOP DROP ;
: .VALUE ." Value: " V @ D @ 2DUP GCD TUCK / .. / DUP 1 = IF DROP ELSE ." /" . THEN ;
: .NASH CR .P1 CR .P2 CR .VALUE ; \ needs to indicate when strategy ratios are giving saddle points
