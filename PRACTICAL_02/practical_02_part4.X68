*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000
START:                  ; first instruction of program

* Put program code here
    MOVE.L  $554,   D0
    MOVE.L  #$754,  D1
    MOVE.L  #200,   D2
    MOVE.L  #$101,  D3
    
    MOVE.L  D0,    $3000 
    MOVE.L  D1,    $2900
    MOVE.L  D2,    $2662
    MOVE.L  D3,    $1432
    
    MOVE.W  #200,  $3000
    MOVE.W  #$400, $2900
    MOVE.W  #%10, $2662
    MOVE.W  #$900, $1432
    
    MOVE.B  #200, $3000
    MOVE.B  #$32,  $2900
    MOVE.B  #%11001111, $2662
    MOVE.B  #%1011001, $1432

    SIMHALT             ; halt simulator

* Put variables and constants here

    END    START        ; last line of source

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
