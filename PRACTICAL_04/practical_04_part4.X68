*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
        ORG     $1000
START:
        MOVE.B  #$64, $3000      ; Player Health = 100
        MOVE.B  #$00, $3001      ; Player Points
        MOVE.B  #$05, $3002      ; Player X Position
        MOVE.B  #$05, $3003      ; Player Y Position

        MOVE.B  #$64, $3010      ; Boss Health = 50
        MOVE.B  #$10, $3011      ; Boss X Position
        MOVE.B  #$15, $3012      ; Boss Y Position

        LEA     $3000, A1        ; A1 -> Player Health
        LEA     $3010, A2        ; A2 -> Boss Health

LOOP:
        BSR     PLAYER_MOVE
        BSR     TAKING_DAMAGE
        BSR     HEALTH_PICKUP
        BSR     ATTACK_BOSS
        BSR     CHECK_GAME_STATE
        BRA     LOOP

PLAYER_MOVE:
        MOVE.B  $3002, D0
        ADD.B   #1, D0           
        MOVE.B  D0, $3002
        RTS                      ; Return to loop

TAKING_DAMAGE:
        SUB.B   #10, (A1)        ; Player takes damage
        RTS                      ; Return to loop

HEALTH_PICKUP:
        ADD.B   #5, (A1)         ; Add health to player
        RTS                      ; Return to loop

ATTACK_BOSS:
        SUB.B   #20, (A2)        ; Boss loses health
        ADD.B   #10, $3001       ; Add points to player
        RTS                      ; Return to loop

CHECK_GAME_STATE:
        MOVE.B  (A1), D1         ; Player health
        BEQ     GAME_OVER

        MOVE.B  (A2), D2         ; Boss health
        BEQ     GAME_WIN
        RTS

GAME_OVER:
        MOVE.B  #$00, $3001      ; Lose all points
        BRA     END_GAME

GAME_WIN:
        ADD.B   #50, $3001       ; Bonus points
        BRA     END_GAME

END_GAME:
        STOP    #$2700           ; Program ends cleanly
        
        SIMHALT         ; halt simulator
        
* Put variables and constants here

        END     START   ; last line of source

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
