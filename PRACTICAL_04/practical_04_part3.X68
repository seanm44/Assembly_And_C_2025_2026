*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000
START:                  ; first instruction of program

* Put program code here
    ;move health to memory location $3000
    MOVE.B #100, $3000
    
    ;load memory address $3000 into A1
    LEA $3000, A1
    
    ;Branch to TAKING_DAMAGE
    BSR     TAKING_DAMAGE
    
    BACK_IN_THE_GAME:
    ;help player out
    BSR     HEALTH_PICKUP
    BRA     GAME_END
    
    TAKING_DAMAGE:
    ;hit by npc
    SUB.B #20, (A1)
    BRA     BACK_IN_THE_GAME
    
    HEALTH_PICKUP:
    ;pickup health found
    ADD.B #10, (A1)
    RTS
    
    GAME_END:
    ; game over
    MOVE.B #$00, (A1)
    

    SIMHALT             ; halt simulator
    

* Put variables and constants here

    END    START        ; last line of source

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
