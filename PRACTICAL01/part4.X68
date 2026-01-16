*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000
START:                  ; first instruction of program
    LEA text, A1
    MOVE #4, D0
    TRAP #15
    
    MOVE #14, D0
    TRAP #15
    
    MOVE #3, D0
    TRAP #15
    
* Put program code here

    SIMHALT             ; halt simulator

text:   dc.b 'Data Register' , 0

* Put variables and constants here

    END    START        ; last line of source

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
