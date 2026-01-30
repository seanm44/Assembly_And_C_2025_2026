*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000
START:                  ; first instruction of program

* Put program code here
     

    ORG    $1000 

START: 

    LEA    PLAYER_POINTS, A0 
    LEA    PLAYER_HEALTH, A1 
    LEA    BOSS_HEALTH, A2 
    LEA    PLAYER_XY_POS, A3 
    LEA    BOSS_XY_POS, A4 

    MOVE.L #1000, (A0) 
    MOVE.W #100, (A1) 
    MOVE.W #100, (A2) 
    MOVE.W #200, (A3) 
    MOVE.W #250, (A4) 

    MOVE.W (A2), D0 
    SUB.W  #50, D0 
    MOVE.W D0, (A2) 

    MOVE.W (A1), D1 
    ADD.W  #25, D1 
    MOVE.B D1, (A1) 
    MOVE.W (A3), D2 

    SIMHALT             ; halt simulator
    
PLAYER_POINTS   dc.l    0 
PLAYER_HEALTH   dc.w    0 
BOSS_HEALTH     dc.w    0 
PLAYER_XY_POS   dc.w    0 
BOSS_XY_POS     dc.w    0 
    

* Put variables and constants here

    END    START        ; last line of source

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
