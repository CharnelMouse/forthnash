{
Simple Forth script for finding a Nash equilibrium for a two-player zero-sum game.
Checks for saddle points first.
If none, uses simplex method, with the simple tableau format from Williams.
Currently no consideration of integer over/underflow.
To implement: reading games from file, allowing continuation if multiple equilibria.
}

\ starting constants, later will be read from file

4 CONSTANT #ROW
4 CONSTANT #COL

\ data structures

: ARRAY CREATE CELLS ALLOT DOES> SWAP CELLS + ;
: TOP 0 ;

: MATRIX CREATE #ROW #COL * CELLS ALLOT ;  \ dimensions known, don't embed
: & ( addr n -- addr ) OVER ! CELL+ ;

\ example games
\ need to add way to use own payoff matrix instead of a hard-coded one

\ 2x2 games
\ saddle
\ MATRIX GAME
\ GAME
\ 1 & 2 &
\ 3 & 4 &
\ DROP
\ no saddle
\ MATRIX GAME
\ GAME
\ 3 & 6 &
\ 5 & 4 &
\ DROP

\ 3x3 game
\ saddle
\ MATRIX GAME
\ GAME
\ 1 & 2 & 3 &
\ 4 & 5 & 6 &
\ 7 & 8 & 9 &
\ DROP
\ no saddle
\ MATRIX GAME
\ GAME
\ 1 & 2 & 7 &
\ 6 & 5 & 4 &
\ 3 & 8 & 9 &
\ DROP

\ 4x4 game
MATRIX GAME
GAME
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

: STRUCT 0 ;
: FIELD CREATE OVER , + DOES> @ CELLS + ;
: /STRUCT CONSTANT ;

STRUCT
#ROW #COL * FIELD A
#ROW        FIELD B
     #COL   FIELD C
#ROW        FIELD ROW-LABELS
     #COL   FIELD COL-LABELS
1           FIELD V \ Might not need, used strat values will add to this for solved schema
1           FIELD D
/STRUCT SCHEMA-SIZE
: SCHEMA CREATE SCHEMA-SIZE CELLS ALLOT ;

: P1-LABELS #ROW 1+ 1 DO DUP I      SWAP ! CELL+ LOOP ;
: P2-LABELS #COL 1+ 1 DO DUP I -1 * SWAP ! CELL+ LOOP ;
: INDEX CELLS + ;
: ROW #COL * CELLS + ;
: REPFILL DO DUP I ! CELL +LOOP DROP ;
SCHEMA SCHEMA1
GAME SCHEMA1 A #ROW #COL * CELLS MOVE
 1 SCHEMA1 B SCHEMA1 C          SWAP REPFILL
-1 SCHEMA1 C SCHEMA1 ROW-LABELS SWAP REPFILL
SCHEMA1 ROW-LABELS P1-LABELS DROP
SCHEMA1 COL-LABELS P2-LABELS DROP
0 SCHEMA1 V !
1 SCHEMA1 D !

\ for manual testing
: .RP DUP 0< IF DROP 1+ SPACES ELSE      SWAP .R SPACE THEN ;
: .RN DUP 0> IF DROP 1+ SPACES ELSE -1 * SWAP .R SPACE THEN ;
: ?RP @ .RP ;
: ?RN @ .RN ;
: .| [CHAR] | EMIT SPACE ;

: .ARRAY   (    addr n ) 0 DO    DUP  I INDEX ?               LOOP DROP  ;
: .RARRAY  ( +n addr n ) 0 DO    2DUP I INDEX @ SWAP .R SPACE LOOP 2DROP ;
: .RPARRAY ( +n addr n ) 0 DO    2DUP I INDEX ?RP             LOOP 2DROP ;
: .RNARRAY ( +n addr n ) 0 DO    2DUP I INDEX ?RN             LOOP 2DROP ;
: .MATRIX-ROW ( addr n -- ) ROW #COL .ARRAY ;
: .MATRIX ( addr )  #ROW 0 DO CR DUP I .MATRIX-ROW LOOP DROP ;
: .A-ROW A SWAP ROW #COL .RARRAY ;
: .B-EL B SWAP INDEX @ SWAP .R SPACE ;
: .RIGHT-LABEL ROW-LABELS SWAP INDEX ?RN ;
: .LEFT-LABEL ROW-LABELS SWAP INDEX ?RP ;
: .MAIN-ROW ( +n r ) SCHEMA1 3DUP .LEFT-LABEL 3DUP .A-ROW .| 3DUP .B-EL .RIGHT-LABEL ;
: .MAIN-ROWS ( +n ) #ROW 0 DO DUP I .MAIN-ROW CR LOOP DROP  ;

: .GAME GAME .MATRIX ;
: .ROWMINS SCHEMA1 ROWMINS #ROW .ARRAY ;
: .COLMAXS SCHEMA1 COLMAXS #COL .ARRAY ;
: .P1-BASES SCHEMA1 COL-LABELS #COL .RPARRAY ;
: .P2-FREES SCHEMA1 COL-LABELS #COL .RNARRAY ;
: .C-ROW SCHEMA1 C #COL .RARRAY ;
: .V SCHEMA1 V @ SWAP .R ;
: .-N 0 DO [CHAR] - EMIT LOOP ;
: .LINE ( +n ) 1+ DUP #COL * .-N [CHAR] + EMIT .-N ;
: .D SCHEMA1 D ? ;
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
: TOP-LEFT-VALUE    (         -- el ) GAME @ DUP 0 COLMAXS ! ;
: TOP-ROW-VALUE     (     col -- el ) GAME OVER INDEX @ DUP ROT COLMAXS ! ;
: NONTOP-LEFT-VALUE ( row     -- el ) GAME SWAP ROW @ DUP 0 UPDATE-COLMAX ;
: NONTOP-ROW-VALUE  ( row col -- el ) TUCK GAME SWAP INDEX SWAP ROW @ DUP ROT UPDATE-COLMAX ;
\ after each non-left element, roll the rowmin
: TOP-NONLEFT-ROW    ( el     -- el ) #COL 1 DO     I TOP-ROW-VALUE        MIN      LOOP ;
: NONTOP-NONLEFT-ROW ( el row -- el ) #COL 1 DO DUP I NONTOP-ROW-VALUE ROT MIN SWAP LOOP DROP ;
: TOP-ROW        TOP-LEFT-VALUE         TOP-NONLEFT-ROW    0    ROWMINS ! ;
: NONTOP-ROW DUP NONTOP-LEFT-VALUE OVER NONTOP-NONLEFT-ROW SWAP ROWMINS ! ;
: OTHER-ROWS #ROW 1 ?DO I NONTOP-ROW LOOP ;
: FIND-EXTREMES TOP-ROW OTHER-ROWS ;

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

\ Simplex algorithm
\ Chooses col based on smallest value, rather than checking -rc/p values

: UNSOLVED? #COL 0 DO SCHEMA1 C I INDEX @ 0< IF TRUE UNLOOP EXIT THEN LOOP FALSE ;

: INIT-COL 0 SCHEMA1 C @ ;
: ROLL-COL TUCK SCHEMA1 C SWAP INDEX @ 2DUP > IF ROT 2NIP SWAP ELSE DROP NIP THEN ;
: P-COL INIT-COL #COL 1 ?DO I ROLL-COL LOOP PIVOT-COLVAL ! PIVOT-COL ! ;

: INIT-ROW -1 PIVOT-ROW ! 0 PIVOT-VAL ! 1 PIVOT-ROWVAL ! ;
: ROW-VALS ( n -- rv av ) SCHEMA1 B OVER INDEX @ SCHEMA1 A ROT ROW PIVOT-COL @ INDEX @ ;
: LOWER-RAT? ( r2 a2 ) PIVOT-ROWVAL @ * SWAP PIVOT-VAL @ * > ; \ r2/a2 < r/p ? for a2, p positive
: REPLACE-ROW PIVOT-VAL ! PIVOT-ROWVAL ! PIVOT-ROW ! ;
: LOWER-RAT ( n -- rv av ) 2DUP LOWER-RAT? IF REPLACE-ROW ELSE 3DROP THEN ;
: ROLL-ROW DUP ROW-VALS DUP 0< IF 3DROP ELSE LOWER-RAT THEN ;
: P-ROW INIT-ROW #ROW 0 DO I ROLL-ROW LOOP ;

: B-MINDET SCHEMA1 B OVER INDEX @ PIVOT-VAL @ * SCHEMA1 A ROT ROW PIVOT-COL @ INDEX @ PIVOT-ROWVAL @ * - ;
: GO-B-EL DUP B-MINDET SCHEMA1 D @ / SCHEMA1 B ROT INDEX ! ;
: GO-B-ROW DUP PIVOT-ROW @ <> IF GO-B-EL ELSE DROP THEN ;
: GO-B #ROW 0 DO I GO-B-ROW LOOP ;

: C-MINDET SCHEMA1 C OVER INDEX @ PIVOT-VAL @ * SCHEMA1 A PIVOT-ROW @ ROW ROT INDEX @ PIVOT-COLVAL @ * - ;
: GO-C-EL DUP C-MINDET SCHEMA1 D @ / SCHEMA1 C ROT INDEX ! ;
: GO-C-COL DUP PIVOT-COL @ <> IF GO-C-EL ELSE DROP THEN ;
: GO-C #COL 0 DO I GO-C-COL LOOP ;

: RV ( c -- rv ) SCHEMA1 A PIVOT-ROW @ ROW SWAP INDEX @ ;
: CV ( r -- cv ) SCHEMA1 A SWAP ROW PIVOT-COL @ INDEX @ ;
: NON-ORTHOG-VALUE ( r c addr -- n ) @ PIVOT-VAL @ * -ROT RV SWAP CV * - SCHEMA1 D @ / ;
: NON-ORTHOG-EL ( r c ) 2DUP SCHEMA1 A SWAP INDEX SWAP ROW >R R@ NON-ORTHOG-VALUE R> ! ;
: NON-ORTHOG-COL ( r c ) DUP PIVOT-COL @ = IF 2DROP ELSE NON-ORTHOG-EL THEN ;
: NON-ORTHOG-ROW ( r ) DUP PIVOT-ROW @ <> IF #COL 0 DO DUP I NON-ORTHOG-COL LOOP THEN DROP ;
: NON-ORTHOG #ROW 0 DO I NON-ORTHOG-ROW LOOP ;

: NEG! ( addr -- ) DUP @ -1 * SWAP ! ;
: NEG-A ( pcol prow row --) TUCK <> IF SCHEMA1 A SWAP ROW SWAP INDEX NEG! ELSE 2DROP THEN ; 
: NEG-C SCHEMA1 C SWAP INDEX NEG! ;
: NEG-COL PIVOT-COL @ DUP PIVOT-ROW @ #ROW 0 DO 2DUP I NEG-A LOOP 2DROP NEG-C ;

: PIVOT-ADDR SCHEMA1 A PIVOT-ROW @ ROW PIVOT-COL @ INDEX ;
: SWAP-SELF SCHEMA1 D @ PIVOT-ADDR ! PIVOT-VAL @ SCHEMA1 D ! ; \ less ops than using MEM-SWAP

: MEM-SWAP 2DUP @ SWAP @ ROT ! SWAP ! ;
: SWAP-LABELS SCHEMA1 ROW-LABELS PIVOT-ROW @ INDEX SCHEMA1 COL-LABELS PIVOT-COL @ INDEX MEM-SWAP ;

: GO GO-B GO-C NON-ORTHOG NEG-COL SWAP-SELF SWAP-LABELS ;

: PIVOT P-COL P-ROW GO ;
: SIMPLEX BEGIN UNSOLVED? WHILE PIVOT REPEAT ;

: SADDLE? ROW-MINMAX DUP COL-MAXMIN = ;

\ Strategies from saddle point solutions
: SP1 #ROW 0 DO I 2DUP ROWMINS @ = 1 AND SWAP P1-STRAT ! LOOP DROP ;
: SP2 #COL 0 DO I 2DUP COLMAXS @ = 1 AND SWAP P2-STRAT ! LOOP DROP ;
: SADDLE ( saddle-value -- ) DUP SCHEMA1 D ! 1 SCHEMA1 V ! DUP SP1 SP2 ;

\ Strategies from solved schema
\ We set V here instead of on each pivot,
\ since at solution time it's equal to either
\ player's solution sum
: P1 1-     P1-STRAT ;
: P2 -1 XOR P2-STRAT ;
: TO-ZERO NIP 0 SWAP ;
: ROW-LABEL DUP 0< IF P2         ELSE P1 TO-ZERO THEN ! ;
: COL-LABEL DUP 0< IF P2 TO-ZERO ELSE P1         THEN ! ;
: ROW-STRATS #ROW 0 DO I SCHEMA1 B OVER INDEX @ SCHEMA1 ROW-LABELS ROT INDEX @ ROW-LABEL LOOP ;
: COL-STRATS #COL 0 DO I SCHEMA1 C OVER INDEX @ SCHEMA1 COL-LABELS ROT INDEX @ COL-LABEL LOOP ;
: MIXED-STRATS ROW-STRATS COL-STRATS ;
: MIXED-VALUE 0 SCHEMA1 V ! #ROW 0 DO I P1-STRAT @ SCHEMA1 V +! LOOP ;
: MIXED SIMPLEX MIXED-STRATS MIXED-VALUE ;

: NASH FIND-EXTREMES SADDLE? IF SADDLE ." Saddle" ELSE DROP MIXED ." Mixed" THEN ;

: GCD 2DUP < IF SWAP THEN DUP 0= IF DROP ELSE BEGIN TUCK MOD DUP 0= UNTIL DROP THEN ;
: GCD-ROLL CELLS + @ DUP 0= IF DROP ELSE GCD THEN ;
: GCD-VEC ( addr len -- n ) OVER @ SWAP 1 ?DO OVER I GCD-ROLL LOOP NIP ;

: .. DUP 0< (D.) TYPE ; \ like ., but without the ending space
: .P1 ." P1: " TOP P1-STRAT #ROW GCD-VEC TOP P1-STRAT @ OVER / .. #ROW 1 ?DO ." :" I P1-STRAT @ OVER / .. LOOP DROP ;
: .P2 ." P2: " TOP P2-STRAT #COL GCD-VEC TOP P2-STRAT @ OVER / .. #COL 1 ?DO ." :" I P2-STRAT @ OVER / .. LOOP DROP ;
: .VALUE ." Value: " SCHEMA1 V @ SCHEMA1 D @ 2DUP GCD TUCK / .. / DUP 1 = IF DROP ELSE ." /" . THEN ;
: .NASH CR .P1 CR .P2 CR .VALUE ; \ needs to indicate when strategy ratios are giving saddle points
