    ORG    $1000
START:                  ; First instruction of program

*-----------------------------------------------------------
* Section       : Trap Codes
* Description   : Trap Codes used throughout the game
*-----------------------------------------------------------
TC_SCREEN   EQU         33          ; Screen size information trap code
TC_S_SIZE   EQU         00          ; Places 0 in D1 to retrieve screen size
TC_KEYCODE  EQU         19          ; Check for pressed keys
TC_DBL_BUF  EQU         92          ; Double Buffer Screen Trap Code
TC_CURSR_P  EQU         11          ; Trap code cursor position
TC_EXIT     EQU         09          ; Exit Trapcode
TC_DELAY    EQU         23          ; Sleep D1.W milliseconds

*-----------------------------------------------------------
* Section       : Player Setup
* Description   : Basketball player properties
*-----------------------------------------------------------
PLYR_W_INIT EQU         16          ; Ball diameter (width)
PLYR_H_INIT EQU         16          ; Ball diameter (height)
PLYR_DFLT_V EQU         00          ; Default Player Velocity
PLYR_JUMP_V EQU        -22          ; Player Jump Velocity
PLYR_DFLT_G EQU         03          ; Default Gravity - faster fall
PLYR_MAX_HP EQU         100         ; Player Max Health

GND_TRUE    EQU         01          ; Player on Ground True
GND_FALSE   EQU         00          ; Player on Ground False


*-----------------------------------------------------------
* Section       : Obstacle Setup
* Description   : Brick obstacle properties
*-----------------------------------------------------------
BRICK_W     EQU         14          ; Brick Width
BRICK_H     EQU         26          ; Brick Height (tall to jump over)
BRICK_SPD   EQU         15          ; Brick Move Speed
BRICK_DMG   EQU         20          ; Damage dealt to player

*-----------------------------------------------------------
* Section       : Health Pack Setup
* Description   : Green heal rectangle properties
*-----------------------------------------------------------
HEAL_W      EQU         10          ; Heal item Width
HEAL_H      EQU         10          ; Heal item Height
HEAL_SPD    EQU         08          ; Heal item Move Speed
HEAL_AMT    EQU         10          ; Health restored

*-----------------------------------------------------------
* Section       : Keyboard Keys
*-----------------------------------------------------------
SPACEBAR    EQU         $20         ; Spacebar ASCII Keycode
ESCAPE      EQU         $1B         ; Escape ASCII Keycode
RESTART_KEY EQU         $72         ; R key to Restart (lowercase r)

TXT_WHITE   EQU         15          ; Bright white text
TXT_BLACK   EQU         00          ; Black background

*-----------------------------------------------------------
* Subroutine    : Initialise
* Description   : Initialise game data and screen
*-----------------------------------------------------------
INITIALISE:
   
    ; Screen Size
    MOVE.B  #TC_SCREEN, D0
    MOVE.L  #TC_S_SIZE, D1
    TRAP    #15
    MOVE.W  D1,         SCREEN_H
    SWAP    D1
    MOVE.W  D1,         SCREEN_W

    ; Place Player left-center (x = screen_w / 4)
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    DIVU    #04,        D1          ; Quarter width for X
    MOVE.L  D1,         PLAYER_X

    ; Place Player on ground (y = screen_h / 2)
    CLR.L   D1
    MOVE.W  SCREEN_H,   D1
    DIVU    #02,        D1
    MOVE.L  D1,         PLAYER_Y

    ; Initialise Player Health
    MOVE.L  #PLYR_MAX_HP, PLAYER_HP

    ; Initialise Player Score
    CLR.L   D1
    MOVE.L  D1,         PLAYER_SCORE

    ; Initialise Player Velocity
    MOVE.L  #PLYR_DFLT_V, PLYR_VELOCITY

    ; Initialise Player Gravity
    MOVE.L  #PLYR_DFLT_G, PLYR_GRAVITY

    ; Initialise Player on Ground
    MOVE.L  #GND_TRUE,  PLYR_ON_GND

    ; Initial Brick Position (right edge, ground level)
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    MOVE.L  D1,         BRICK_X

    CLR.L   D1
    MOVE.W  SCREEN_H,   D1
    DIVU    #02,        D1
    SUB.L   #10,        D1          ; Brick overlaps player ground level
    MOVE.L  D1,         BRICK_Y

    ; Initial Heal Position (further off screen right)
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    ADD.L   #160,       D1          ; Offset to appear after brick
    MOVE.L  D1,         HEAL_X

    CLR.L   D1
    MOVE.W  SCREEN_H,   D1
    DIVU    #02,        D1
    MOVE.L  D1,         HEAL_Y      ; Heal sits on ground (same level)

    ; Init Current Key to zero
    CLR.L   D1
    MOVE.L  D1,         CURRENT_KEY

    ; Enable Double Buffer
    MOVE.B  #TC_DBL_BUF,D0
    MOVE.B  #17,        D1
    TRAP    #15

    ; Clear Screen
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$FF00,     D1
    TRAP    #15

*-----------------------------------------------------------
* Subroutine    : Game
* Description   : Main game entry and loop
*-----------------------------------------------------------
GAME:
    BSR     PLAY_RUN
GAMELOOP:
    BSR     INPUT
    BSR     UPDATE
    BSR     IS_PLAYER_ON_GND
    BSR     CHECK_COLLISIONS
    BSR     DRAW
    BSR     DELAY                   ; Slow game to playable speed
    BRA     GAMELOOP

*-----------------------------------------------------------
* Subroutine    : Input
* Description   : Process Keyboard Input
*-----------------------------------------------------------
INPUT:
    CLR.L   D1
    MOVE.B  #TC_KEYCODE,D0
    TRAP    #15
    MOVE.B  D1,         D2
    CMP.B   #00,        D2
    BEQ     PROCESS_INPUT
    TRAP    #15
    CMP.B   #$FF,       D1
    BEQ     PROCESS_INPUT
    RTS

*-----------------------------------------------------------
* Subroutine    : Process Input
* Description   : Branch based on key pressed
*-----------------------------------------------------------
PROCESS_INPUT:
    MOVE.L  D2,         CURRENT_KEY
    CMP.L   #ESCAPE,    CURRENT_KEY
    BEQ     EXIT
    CMP.L   #SPACEBAR,  CURRENT_KEY
    BEQ     JUMP
    BRA     IDLE

*-----------------------------------------------------------
* Subroutine    : Update
* Description   : Update player physics, brick, and heal item
*-----------------------------------------------------------
UPDATE:
    ; Update player Y with velocity and gravity
    MOVE.L  PLYR_VELOCITY, D1
    MOVE.L  PLYR_GRAVITY,  D2
    ADD.L   D2,         D1
    MOVE.L  D1,         PLYR_VELOCITY
    ADD.L   PLAYER_Y,   D1
    MOVE.L  D1,         PLAYER_Y

    ; Increment score each frame (survival)
    ADD.L   #01,        PLAYER_SCORE

    ; Move Brick left
    MOVE.L  BRICK_X,    D1
    CMP.L   #00,        D1
    BLE     RESET_BRICK
    SUB.L   #BRICK_SPD, BRICK_X
    BRA     UPDATE_HEAL

RESET_BRICK:
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    MOVE.L  D1,         BRICK_X

UPDATE_HEAL:
    ; Move Heal item left
    MOVE.L  HEAL_X,     D1
    CMP.L   #00,        D1
    BLE     RESET_HEAL
    SUB.L   #HEAL_SPD,  HEAL_X
    RTS

RESET_HEAL:
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    ADD.L   #600,       D1          ; Spawn far off screen - makes heal rare
    MOVE.L  D1,         HEAL_X
    RTS

*-----------------------------------------------------------
* Subroutine    : Is Player On Ground
* Description   : Check if player is on or above ground
*-----------------------------------------------------------
IS_PLAYER_ON_GND:
    CLR.L   D1
    CLR.L   D2
    MOVE.W  SCREEN_H,   D1
    DIVU    #02,        D1          ; Ground level = screen_h / 2
    MOVE.L  PLAYER_Y,   D2
    CMP     D1,         D2          ; Compare player Y to ground
    BGE     SET_ON_GROUND
    BLT     SET_OFF_GROUND
    RTS

*-----------------------------------------------------------
* Subroutine    : Set On Ground
*-----------------------------------------------------------
SET_ON_GROUND:
    CLR.L   D1
    MOVE.W  SCREEN_H,   D1
    DIVU    #02,        D1
    MOVE.L  D1,         PLAYER_Y    ; Snap to ground
    MOVE.L  #00,        PLYR_VELOCITY
    MOVE.L  #GND_TRUE,  PLYR_ON_GND
    RTS

*-----------------------------------------------------------
* Subroutine    : Set Off Ground
*-----------------------------------------------------------
SET_OFF_GROUND:
    MOVE.L  #GND_FALSE, PLYR_ON_GND
    RTS

*-----------------------------------------------------------
* Subroutine    : Jump
* Description   : Apply upward velocity if on ground
*-----------------------------------------------------------
JUMP:
    CMP.L   #GND_TRUE,  PLYR_ON_GND
    BEQ     PERFORM_JUMP
    BRA     JUMP_DONE
PERFORM_JUMP:
    BSR     PLAY_JUMP
    MOVE.L  #PLYR_JUMP_V, PLYR_VELOCITY
    RTS
JUMP_DONE:
    RTS

*-----------------------------------------------------------
* Subroutine    : Idle
*-----------------------------------------------------------
IDLE:
    BSR     PLAY_RUN
    RTS

*-----------------------------------------------------------
* Subroutine    : Delay
*-----------------------------------------------------------
DELAY:
    MOVE.W  #2,         D1          ; 2ms per frame
    MOVE.B  #TC_DELAY,  D0
    TRAP    #15
    RTS

*-----------------------------------------------------------
* Subroutines   : Sound Load and Play
*-----------------------------------------------------------
RUN_LOAD:
    MOVE    #71,        D0
    TRAP    #15
    RTS

PLAY_RUN:
    MOVE    #72,        D0
    TRAP    #15
    RTS

JUMP_LOAD:
    MOVE    #71,        D0
    TRAP    #15
    RTS

PLAY_JUMP:
    MOVE    #72,        D0
    TRAP    #15
    RTS

OPPS_LOAD:
    MOVE    #71,        D0
    TRAP    #15
    RTS

PLAY_OPPS:
    MOVE    #72,        D0
    TRAP    #15
    RTS

*-----------------------------------------------------------
* Subroutine    : Draw
* Description   : Render full scene each frame
*-----------------------------------------------------------
DRAW:
    ; Swap to back buffer
    MOVE.B  #94,        D0
    TRAP    #15

    ; Clear screen
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$FF00,     D1
    TRAP    #15

    BSR     DRAW_PLAYER
    BSR     DRAW_BRICK
    BSR     DRAW_HEALER
    BSR     DRAW_HUD
    RTS

*-----------------------------------------------------------
* Subroutine    : Draw HUD
* Description   : Draw Score, Health and Key Info
*-----------------------------------------------------------
DRAW_HUD:
    ; This stops the green healer fill bleeding into text background
    MOVE.L  #BLACK,     D1
    MOVE.B  #80,        D0          ; Pen color = black
    TRAP    #15
    MOVE.L  #BLACK,     D1
    MOVE.B  #81,        D0          ; Fill color = black
    TRAP    #15

    ; Score Label
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$0201,     D1          ; Col 02, Row 01
    TRAP    #15
    LEA     SCORE_MSG,  A1
    MOVE    #13,        D0
    TRAP    #15

    ; Score Value
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$0901,     D1          ; Col 09, Row 01
    TRAP    #15
    MOVE.B  #03,        D0
    MOVE.L  PLAYER_SCORE,D1
    TRAP    #15

    ; Health Label
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$0202,     D1          ; Col 02, Row 02
    TRAP    #15
    LEA     HEALTH_MSG, A1
    MOVE    #13,        D0
    TRAP    #15

    ; Health Value
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$0A02,     D1          ; Col 10, Row 02
    TRAP    #15
    MOVE.B  #03,        D0
    MOVE.L  PLAYER_HP,  D1
    TRAP    #15

    ; Keys Info Label
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$2001,     D1          ; Col 32, Row 01
    TRAP    #15
    LEA     KEYCODE_MSG,A1
    MOVE    #13,        D0
    TRAP    #15

    ; Key Value
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$3001,     D1          ; Col 48, Row 01
    TRAP    #15
    MOVE.L  CURRENT_KEY,D1
    MOVE.B  #03,        D0
    TRAP    #15

    ; Controls Hint
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$0203,     D1          ; Col 02, Row 03
    TRAP    #15
    LEA     HINT_MSG,   A1
    MOVE    #13,        D0
    TRAP    #15

    RTS

*-----------------------------------------------------------
* Subroutine    : Draw Player (Basketball)
* Description   : Draw solid orange circle
*-----------------------------------------------------------
DRAW_PLAYER:
    MOVE.L  #ORANGE,    D1
    MOVE.B  #80,        D0
    TRAP    #15
    MOVE.L  #ORANGE,    D1          ; Set fill color to orange
    MOVE.B  #81,        D0
    TRAP    #15

    MOVE.L  PLAYER_X,   D1          ; X1
    MOVE.L  PLAYER_Y,   D2          ; Y1
    MOVE.L  PLAYER_X,   D3
    ADD.L   #PLYR_W_INIT,D3         ; X2 = X1 + diameter
    MOVE.L  PLAYER_Y,   D4
    ADD.L   #PLYR_H_INIT,D4         ; Y2 = Y1 + diameter
    MOVE.B  #88,        D0          ; Draw filled ellipse (circle)
    TRAP    #15

    RTS

*-----------------------------------------------------------
* Subroutine    : Draw Brick
* Description   : Draw solid brown brick obstacle
*-----------------------------------------------------------
DRAW_BRICK:
    ; Set pen color (outline) to brown
    MOVE.L  #BROWN,     D1
    MOVE.B  #80,        D0
    TRAP    #15
    ; Set fill color to brown
    MOVE.L  #BROWN,     D1
    MOVE.B  #81,        D0
    TRAP    #15

    MOVE.L  BRICK_X,    D1
    MOVE.L  BRICK_Y,    D2
    MOVE.L  BRICK_X,    D3
    ADD.L   #BRICK_W,   D3
    MOVE.L  BRICK_Y,    D4
    ADD.L   #BRICK_H,   D4
    MOVE.B  #87,        D0          ; Draw filled rectangle
    TRAP    #15

    RTS

*-----------------------------------------------------------
* Subroutine    : Draw Healer
* Description   : Draw solid green health pack
*-----------------------------------------------------------
DRAW_HEALER:
    ; Set pen color (outline) to green
    MOVE.L  #GREEN,     D1
    MOVE.B  #80,        D0
    TRAP    #15
    ; Set fill color to green
    MOVE.L  #GREEN,     D1
    MOVE.B  #81,        D0
    TRAP    #15

    MOVE.L  HEAL_X,     D1
    MOVE.L  HEAL_Y,     D2
    MOVE.L  HEAL_X,     D3
    ADD.L   #HEAL_W,    D3
    MOVE.L  HEAL_Y,     D4
    ADD.L   #HEAL_H,    D4
    MOVE.B  #87,        D0
    TRAP    #15

    RTS

*-----------------------------------------------------------
* Subroutine    : Check Collisions
* Description   : Check both brick and heal collisions
*-----------------------------------------------------------
CHECK_COLLISIONS:
    BSR     CHECK_BRICK_COL
    BSR     CHECK_HEAL_COL
    RTS

*-----------------------------------------------------------
* Subroutine    : Check Brick Collision
* Description   : AABB check - brick does 20 damage
*-----------------------------------------------------------
CHECK_BRICK_COL:
    CLR.L   D1
    CLR.L   D2

    ; Check 1: PLAYER_X < BRICK_X + BRICK_W
    MOVE.L  PLAYER_X,   D1
    MOVE.L  BRICK_X,    D2
    ADD.L   #BRICK_W,   D2
    CMP.L   D2,         D1          ; D1 - D2
    BGE     BRICK_NO_HIT            ; Player is right of brick

    ; Check 2: PLAYER_X + PLAYER_W > BRICK_X
    MOVE.L  PLAYER_X,   D1
    ADD.L   #PLYR_W_INIT,D1
    MOVE.L  BRICK_X,    D2
    CMP.L   D2,         D1
    BLE     BRICK_NO_HIT            ; Player is left of brick

    ; Check 3: PLAYER_Y < BRICK_Y + BRICK_H
    MOVE.L  PLAYER_Y,   D1
    MOVE.L  BRICK_Y,    D2
    ADD.L   #BRICK_H,   D2
    CMP.L   D2,         D1
    BGE     BRICK_NO_HIT            ; Player is below brick

    ; Check 4: PLAYER_Y + PLAYER_H > BRICK_Y
    MOVE.L  PLAYER_Y,   D1
    ADD.L   #PLYR_H_INIT,D1
    MOVE.L  BRICK_Y,    D2
    CMP.L   D2,         D1
    BLE     BRICK_NO_HIT            ; Player is above brick

    BRA     BRICK_HIT               ; All checks passed - collision!

BRICK_NO_HIT:
    RTS

BRICK_HIT:
    MOVE.L  PLAYER_HP,  D1
    SUB.L   #BRICK_DMG, D1          ; Deduct 20 HP
    CMP.L   #00,        D1
    BLE     GAME_OVER               ; Dead if HP <= 0
    MOVE.L  D1,         PLAYER_HP   ; Save new HP
    ; Reset brick to right side
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    MOVE.L  D1,         BRICK_X
    RTS

*-----------------------------------------------------------
* Subroutine    : Check Heal Collision
* Description   : check - heal pack restores 10 HP
*-----------------------------------------------------------
CHECK_HEAL_COL:
    CLR.L   D1
    CLR.L   D2

    ; Check 1: PLAYER_X < HEAL_X + HEAL_W
    MOVE.L  PLAYER_X,   D1
    MOVE.L  HEAL_X,     D2
    ADD.L   #HEAL_W,    D2
    CMP.L   D2,         D1
    BGE     HEAL_NO_HIT

    ; Check 2: PLAYER_X + PLAYER_W > HEAL_X
    MOVE.L  PLAYER_X,   D1
    ADD.L   #PLYR_W_INIT,D1
    MOVE.L  HEAL_X,     D2
    CMP.L   D2,         D1
    BLE     HEAL_NO_HIT

    ; Check 3: PLAYER_Y < HEAL_Y + HEAL_H
    MOVE.L  PLAYER_Y,   D1
    MOVE.L  HEAL_Y,     D2
    ADD.L   #HEAL_H,    D2
    CMP.L   D2,         D1
    BGE     HEAL_NO_HIT

    ; Check 4: PLAYER_Y + PLAYER_H > HEAL_Y
    MOVE.L  PLAYER_Y,   D1
    ADD.L   #PLYR_H_INIT,D1
    MOVE.L  HEAL_Y,     D2
    CMP.L   D2,         D1
    BLE     HEAL_NO_HIT

    BRA     HEAL_PICKUP

HEAL_NO_HIT:
    RTS

HEAL_PICKUP:
    MOVE.L  PLAYER_HP,  D1
    ADD.L   #HEAL_AMT,  D1          ; Add 10 HP
    CMP.L   #PLYR_MAX_HP, D1        ; Cap at max
    BLE     SET_HEAL_HP
    MOVE.L  #PLYR_MAX_HP, D1
SET_HEAL_HP:
    MOVE.L  D1,         PLAYER_HP
    ; Reset heal item off screen right
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    ADD.L   #200,       D1
    MOVE.L  D1,         HEAL_X
    RTS

*-----------------------------------------------------------
* Subroutine    : Game Over
* Description   : Defeat screen - show score, retry or quit
*-----------------------------------------------------------
GAME_OVER:
    MOVE.L  #00,        PLAYER_HP

    ; Set console text: foreground=white(15), background=black(0)
    MOVE.W  #15,        D1
    MOVE.B  #20,        D0           
    TRAP    #15
    MOVE.W  #00,        D1
    MOVE.B  #21,        D0          
    TRAP    #15

    ; Also reset graphics pen and fill to black
    MOVE.L  #BLACK,     D1
    MOVE.B  #80,        D0
    TRAP    #15
    MOVE.L  #BLACK,     D1
    MOVE.B  #81,        D0
    TRAP    #15

    ; Swap buffer
    MOVE.B  #94,        D0
    TRAP    #15

    ; Clear screen via console
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$FF00,     D1
    TRAP    #15

    ; Draw dark red banner rectangle for title area
    MOVE.L  #$00003388, D1
    MOVE.B  #80,        D0
    TRAP    #15
    MOVE.L  #$00003388, D1
    MOVE.B  #81,        D0
    TRAP    #15
    MOVE.L  #80,        D1
    MOVE.L  #100,       D2
    MOVE.L  #560,       D3
    MOVE.L  #160,       D4
    MOVE.B  #87,        D0
    TRAP    #15

    ; Reset pen/fill black before text
    MOVE.L  #BLACK,     D1
    MOVE.B  #80,        D0
    TRAP    #15
    MOVE.L  #BLACK,     D1
    MOVE.B  #81,        D0
    TRAP    #15

    ; *** DEFEATED *** title
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$1A09,     D1          ; Col 26, Row 9
    TRAP    #15
    LEA     DEFEAT_HDR, A1
    MOVE    #13,        D0
    TRAP    #15

    ; Subtitle line
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$180B,     D1          ; Col 24, Row 11
    TRAP    #15
    LEA     DEFEAT_SUB, A1
    MOVE    #13,        D0
    TRAP    #15

    ; Score label
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$1C0D,     D1          ; Col 28, Row 13
    TRAP    #15
    LEA     FINALSCORE_MSG, A1
    MOVE    #13,        D0
    TRAP    #15

    ; Score value (number)
    MOVE.B  #03,        D0
    MOVE.L  PLAYER_SCORE, D1
    TRAP    #15

    ; Blank line then retry
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$1C0F,     D1          ; Col 28, Row 15
    TRAP    #15
    LEA     RETRY_MSG,  A1
    MOVE    #13,        D0
    TRAP    #15

    ; Quit line
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$1C10,     D1          ; Col 28, Row 16
    TRAP    #15
    LEA     QUIT_MSG,   A1
    MOVE    #13,        D0
    TRAP    #15

DEFEAT_WAIT:
    MOVE.B  #TC_KEYCODE,D0          ; Load keycode trap
    TRAP    #15                     ; D1 = current key (0 if none)
    CMP.B   #RESTART_KEY, D1       ; R pressed?
    BEQ     RESTART
    CMP.B   #ESCAPE,    D1         ; ESC pressed?
    BEQ     EXIT
    BRA     DEFEAT_WAIT             ; Keep polling

*-----------------------------------------------------------
* Subroutine    : Restart
* Description   : Reset all game state and jump back to GAME
*-----------------------------------------------------------
RESTART:
    ; Reset Player to starting position
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    DIVU    #04,        D1
    MOVE.L  D1,         PLAYER_X

    CLR.L   D1
    MOVE.W  SCREEN_H,   D1
    DIVU    #02,        D1
    MOVE.L  D1,         PLAYER_Y

    ; Reset health, score, velocity, gravity, ground
    MOVE.L  #PLYR_MAX_HP,  PLAYER_HP
    CLR.L   D1
    MOVE.L  D1,         PLAYER_SCORE
    MOVE.L  #PLYR_DFLT_V,  PLYR_VELOCITY
    MOVE.L  #PLYR_DFLT_G,  PLYR_GRAVITY
    MOVE.L  #GND_TRUE,     PLYR_ON_GND

    ; Reset Brick
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    MOVE.L  D1,         BRICK_X

    CLR.L   D1
    MOVE.W  SCREEN_H,   D1
    DIVU    #02,        D1
    SUB.L   #10,        D1
    MOVE.L  D1,         BRICK_Y

    ; Reset Heal
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    ADD.L   #600,       D1
    MOVE.L  D1,         HEAL_X

    CLR.L   D1
    MOVE.W  SCREEN_H,   D1
    DIVU    #02,        D1
    MOVE.L  D1,         HEAL_Y

    ; Clear key
    CLR.L   D1
    MOVE.L  D1,         CURRENT_KEY

    ; Clear screen
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$FF00,     D1
    TRAP    #15

    BRA     GAME                    ; Jump back into game loop

*-----------------------------------------------------------
* Subroutine    : EXIT
* Description   : Exit game cleanly
*-----------------------------------------------------------
EXIT:
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$4004,     D1
    TRAP    #15
    LEA     EXIT_MSG,   A1
    MOVE    #13,        D0
    TRAP    #15
    MOVE.B  #TC_EXIT,   D0
    TRAP    #15
    SIMHALT

*-----------------------------------------------------------
* Section       : Messages
*-----------------------------------------------------------
SCORE_MSG       DC.B    'Score : ', 0
HEALTH_MSG      DC.B    'Health: ', 0
KEYCODE_MSG     DC.B    'Key: ', 0
HINT_MSG        DC.B    'SPACE=Jump  ESC=Quit  R=Restart', 0
DEFEAT_HDR      DC.B    'Good Try!', 0
DEFEAT_SUB      DC.B    'You did not survive...', 0
FINALSCORE_MSG  DC.B    'Your Score: ', 0
RETRY_MSG       DC.B    'R = Restart', 0
QUIT_MSG        DC.B    'ESC = Quit', 0
EXIT_MSG        DC.B    'Exiting...', 0

*-----------------------------------------------------------
* Section       : Colors 
*-----------------------------------------------------------
WHITE           EQU     $00FFFFF0   ; White
BLACK           EQU     $00000000   ; Black
ORANGE          EQU     $00008CFF   ; Basketball orange
GREEN           EQU     $0000FF00   ; Heal item green
BROWN           EQU     $0013458B   ; Brick brown

*-----------------------------------------------------------
* Section       : Screen Dimensions
*-----------------------------------------------------------
SCREEN_W        DS.W    01          ; Screen Width
SCREEN_H        DS.W    01          ; Screen Height

*-----------------------------------------------------------
* Section       : Keyboard Input
*-----------------------------------------------------------
CURRENT_KEY     DS.L    01          ; Current Key Pressed

*-----------------------------------------------------------
* Section       : Player State
*-----------------------------------------------------------
PLAYER_X        DS.L    01          ; Player X Position
PLAYER_Y        DS.L    01          ; Player Y Position
PLAYER_HP       DS.L    01          ; Player Health Points
PLAYER_SCORE    DS.L    01          ; Player Score
PLYR_VELOCITY   DS.L    01          ; Player Vertical Velocity
PLYR_GRAVITY    DS.L    01          ; Player Gravity
PLYR_ON_GND     DS.L    01          ; Player On Ground Flag

*-----------------------------------------------------------
* Section       : Brick State
*-----------------------------------------------------------
BRICK_X         DS.L    01          ; Brick X Position
BRICK_Y         DS.L    01          ; Brick Y Position

*-----------------------------------------------------------
* Section       : Heal Item State
*-----------------------------------------------------------
HEAL_X          DS.L    01          ; Heal Item X Position
HEAL_Y          DS.L    01          ; Heal Item Y Position

    END    START
*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
