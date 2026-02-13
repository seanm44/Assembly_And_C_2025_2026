*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*----------------------------------------------------------- 
    ORG     $1000
DAMAGE          EQU     10  ; Damage when Collisions occur
POWER_AMOUNT    EQU     20

START:
    LEA     PLAYER_X, A2            ; Player will move along X axis
    LEA     ENEMY_POSITIONS, A3
    BRA     GAME_LOOP

GAME_LOOP:
    BSR     COUNT_ENEMIES
    MOVE.B  D0, D4

    LEA     MSG_GAMELOOP, A1
    BSR     DRAW

    BSR     UPDATE
    BRA     GAME_LOOP

UPDATE:
    MOVE.B  PLAYER_HEALTH, D1

    LEA     MSG_HEALTH, A1
    BSR     DRAW

    MOVE.B  #3, D0
    TRAP    #15

    LEA     CRLF, A1
    BSR     DRAW

    CMP     #0, D1
    BLE     GAME_OVER
    ADD.L   #1, PLAYER_X
    BSR     COLLISION
    BSR     CHECK_POWERUPS
    RTS

DRAW:
    MOVE.B  #13, D0
    TRAP    #15
    RTS

COLLISION:
    MOVE.B  #0, D5
    LEA     ENEMY_POSITIONS, A3
    
COLLISION_LOOP:
    CMP.B   D5, D4
    BEQ     END_COLLISION

    MOVE.L  (A3)+, D2
    MOVE.L  PLAYER_X, D3

    CMP.L   D2, D3
    BEQ     REDUCE_HEALTH

    ADD.B   #1, D5
    BRA     COLLISION_LOOP

END_COLLISION:
    RTS

REDUCE_HEALTH:
    LEA     MSG_COLLISION, A1
    BSR     DRAW

    SUB.B   #DAMAGE, PLAYER_HEALTH

    LEA     MSG_DAMAGE, A1
    BSR     DRAW
    RTS

CHECK_POWERUPS:
    LEA     POWER_UPS, A4

POWER_LOOP:
    MOVE.L  (A4)+, D2
    CMP.L   #0, D2
    BEQ     END_POWER
    MOVE.L  PLAYER_X, D3
    CMP.L   D2, D3
    BEQ     GIVE_POWER
    BRA     POWER_LOOP

GIVE_POWER:
    LEA     MSG_POWERUP, A1
    BSR     DRAW

    ADD.B   #POWER_AMOUNT, PLAYER_HEALTH
    CMP.B   #100, PLAYER_HEALTH
    BLE     END_POWER
    MOVE.B  #100, PLAYER_HEALTH

END_POWER:
    RTS

COUNT_ENEMIES:
    MOVE.B  #0, D0
    LEA     ENEMY_POSITIONS, A0

COUNT_ENEMIES_LOOP:
    TST.L   (A0)+
    BEQ     END_COUNT
    ADD.B   #1, D0
    BRA     COUNT_ENEMIES_LOOP

END_COUNT:
   RTS

GAME_OVER:
    LEA     MSG_GAMEOVER, A1
    BSR     DRAW
        SIMHALT

PLAYER_X        DC.L    1
PLAYER_HEALTH   DC.B    100
MSG_HEALTH      DC.B    'Health : ',0
MSG_GAMELOOP    DC.B    'Game Loop',0
MSG_COLLISION   DC.B    'Collision',0
MSG_DAMAGE      DC.B    'Taking Damage',0
MSG_POWERUP     DC.B    'Power Up!',0
MSG_GAMEOVER    DC.B    'Game Over',0
CRLF            DC.B    $0D,$0A,0

ENEMY_POSITIONS DC.L    20, 30, 40, 50, 60, 70, 80, 90, 200, 300, 500, 0
POWER_UPS DC.L 10, 55, 220, 0 

        END     START

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
