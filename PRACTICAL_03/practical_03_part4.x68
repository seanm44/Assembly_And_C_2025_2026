*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000
START:                  ; first instruction of program

* Put program code here
    LEA PLAYER_POINTS, A0
    LEA PLAYER_HEALTH, A1
    LEA BOSS_HEALTH, A2
    LEA PLAYER_XY_POS, A3
    LEA BOSS_XY_POS, A4
   
    MOVE.B #$64, (A0)
    
    MOVE.B #$60, (A0)
    
    
    SIMHALT             ; halt simulator
    
PLAYER_POINTS dc.b 
PLAYER_HEALTH dc.b 
BOSS_HEALTH dc.b 
PLAYER_XY_POS dc.b 
BOSS_XY_POS  dc.b 
 

* Put variables and constants here

    END    START        ; last line of source

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
