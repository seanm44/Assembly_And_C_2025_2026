*===========================================================
* Name:         : Sean Maher
* Student Number: C00310393
* Date Created: : 24/02/2025
* Program       : BasketHopper  
* Description   : Side-scrolling survival game. Jump over
*                 brown bricks, collect green health packs
*                 and blue water pickups. Stamina drains
*                 over time, run out and you lose.
*                 Difficulty affects speed and drain rate.
* Controls      : SPACE = Jump  R = Reset  ESC = Quit
*===========================================================
    ORG    $1000               ; Program starts at address $1000
START:                         ; Entry point label

*-----------------------------------------------------------
* Section       : Trap Codes
*-----------------------------------------------------------
TC_SCREEN   EQU     33         ; Task 33 : Query screen dimensions
TC_S_SIZE   EQU     00         ; Sub-code 0 : get width/height into D1
TC_KEYCODE  EQU     19         ; Task 19 : Non-blocking keycheck (returns 0 if nothing pressed)
TC_DBL_BUF  EQU     92         ; Task 92 : Double-buffer control
TC_CURSR_P  EQU     11         ; Task 11 : Set cursor position (D1 high=col, low=row)
TC_EXIT     EQU     09         ; Task 9  : Terminate program
TC_DELAY    EQU     23         ; Task 23 : Sleep D1.W milliseconds

*-----------------------------------------------------------
* Section       : Player Constants
* Description   : Fixed values for player size and physics
*-----------------------------------------------------------
PLYR_W_INIT EQU     16         ; Player sprite width  in pixels
PLYR_H_INIT EQU     16         ; Player sprite height in pixels
PLYR_DFLT_V EQU     00         ; Starting vertical velocity (stationary)
PLYR_JUMP_V EQU    -22         ; Velocity applied on jump (negative = upward)
PLYR_DFLT_G EQU     03         ; Gravity added to velocity each frame
PLYR_MAX_HP EQU     100        ; Maximum player health
PLYR_MAX_ST EQU     100        ; Maximum player stamina

GND_TRUE    EQU     01         ; Flag value: player IS on the ground
GND_FALSE   EQU     00         ; Flag value: player is NOT on the ground

*-----------------------------------------------------------
* Section       : Item Constants
* Description   : Sizes, speeds and amounts for pickups/obstacles
*-----------------------------------------------------------
BRICK_W     EQU     14         ; Brown obstacle width  in pixels
BRICK_H     EQU     26         ; Brown obstacle height in pixels (tall - must jump)
BRICK_DMG   EQU     20         ; Health deducted on brick collision

HEAL_W      EQU     10         ; Green health pickup width  in pixels
HEAL_H      EQU     10         ; Green health pickup height in pixels
HEAL_AMT    EQU     10         ; HP restored when health pickup is collected
HEAL_SPD    EQU     08         ; Pixels the health pickup moves left per frame

WATER_W     EQU     12         ; Blue stamina pickup width  in pixels
WATER_H     EQU     12         ; Blue stamina pickup height in pixels
WATER_AMT   EQU     30         ; Stamina restored when water pickup is collected
WATER_SPD   EQU     10         ; Pixels the water pickup moves left per frame

*-----------------------------------------------------------
* Section       : Difficulty Constants
* Description   : Three difficulty levels selected from the
*                 main menu by pressing D.
*                 Affects brick speed, stamina drain rate,
*                 and how far off-screen pickups respawn
*                 (higher offset = longer wait = rarer).
*-----------------------------------------------------------
DIFF_EASY   EQU     01         ; Difficulty identifier: Easy
DIFF_NORM   EQU     02         ; Difficulty identifier: Normal
DIFF_HARD   EQU     03         ; Difficulty identifier: Hard

SPD_EASY    EQU     08         ; Brick pixels-per-frame on Easy
SPD_NORM    EQU     15         ; Brick pixels-per-frame on Normal
SPD_HARD    EQU     22         ; Brick pixels-per-frame on Hard

; Stamina drain: 1 point drained every N frames.
; Smaller N = faster drain. Hard is very aggressive.
TICK_EASY   EQU     80         ; Easy  : drain every 80 frames (~16 sec to empty)
TICK_NORM   EQU     45         ; Normal: drain every 45 frames (~9 sec  to empty)
TICK_HARD   EQU     14         ; Hard  : drain every 14 frames (~3 sec to empty)

; Heal pickup respawn offset (pixels added to screen width before spawning).
; Larger offset = longer off-screen travel = pickup appears less frequently.
HEAL_SPAWN_EASY EQU  900       ; Easy  : heal is reasonably common
HEAL_SPAWN_NORM EQU  1400      ; Normal: heal is moderately rare
HEAL_SPAWN_HARD EQU  2000      ; Hard  : heal is rare

; Water pickup respawn offset. Always rarer than the heal pickup.
WATER_SPAWN_EASY EQU 1500      ; Easy  : water is uncommon
WATER_SPAWN_NORM EQU 2200      ; Normal: water is rare
WATER_SPAWN_HARD EQU 3200      ; Hard  : water is very rare

*-----------------------------------------------------------
* Section       : Keyboard Key Codes
* Description   : ASCII hex values for keys used in the game
*-----------------------------------------------------------
SPACEBAR      EQU   $20        ; Space bar - used to jump
ESCAPE        EQU   $1B        ; Escape key - quit game
RESTART_KEY   EQU   $72        ; Lowercase 'r' - restart from game over
RESTART_KEY_U EQU   $52        ; Uppercase 'R' - restart from game over
MENU_KEY      EQU   $6D        ; Lowercase 'm' - return to main menu
MENU_KEY_U    EQU   $4D        ; Uppercase 'M' - return to main menu
KEY_1         EQU   $31        ; '1' key - Play option in main menu
KEY_2         EQU   $32        ; '2' key - Quit option in main menu
KEY_D         EQU   $64        ; Lowercase 'd' - cycle difficulty in menu
KEY_D_U       EQU   $44        ; Uppercase 'D' - cycle difficulty in menu

*===========================================================
* Subroutine    : INITIALISE
* Description   : One-time startup. Queries screen size,
*                 enables double-buffering, sets default
*                 difficulty to Normal, clears screen,
*                 then falls through into MAIN_MENU.
*===========================================================
INITIALISE:
    MOVE.B  #TC_SCREEN, D0     ; Select screen-info service
    MOVE.L  #TC_S_SIZE, D1     ; Sub-code 0 = get dimensions
    TRAP    #15                ; Call Easy68k OS
    MOVE.W  D1,     SCREEN_H   ; Low  word of D1 = screen height
    SWAP    D1                 ; Swap halves so width is in low word
    MOVE.W  D1,     SCREEN_W   ; Low  word now = screen width

    MOVE.B  #TC_DBL_BUF,D0    ; Select double-buffer service
    MOVE.B  #17,        D1     ; Sub-code 17 = enable double buffer
    TRAP    #15                ; All subsequent drawing goes to back buffer

    MOVE.L  #DIFF_NORM, DIFFICULTY ; Default to Normal on first launch

    MOVE.B  #TC_CURSR_P,D0    ; Select cursor-position service
    MOVE.W  #$FF00,     D1     ; $FF in high byte = clear whole screen
    TRAP    #15                ; Wipe display before showing menu
    ; No RTS - execution falls straight through to MAIN_MENU

*===========================================================
* Subroutine    : MAIN_MENU
* Description   : Draws the title screen and waits for input.
*                 1 = start game, D = cycle difficulty, 2 = quit.
*
* Column centering maths (80-column screen, 0-indexed):
*   "=========================" 25 chars -> start col 27 ($1B)
*   "B A S K E T H O P P E R"  23 chars -> start col 28 ($1C)
*   "1  -  Play"                10 chars -> start col 35 ($23)
*   "Difficulty: Easy/Hard"     16 chars -> start col 32 ($20)
*   "Difficulty: Normal"        18 chars -> start col 31 ($1F)
*   "(press D to change)"       19 chars -> start col 30 ($1E)
*   "2  -  Quit"                10 chars -> start col 35 ($23)
*===========================================================
MAIN_MENU:
    MOVE.B  #TC_CURSR_P,D0    ; Select cursor service
    MOVE.W  #$FF00,     D1     ; Clear full screen
    TRAP    #15                ; Execute clear

    ; --- Top banner ---
    MOVE.B  #TC_CURSR_P,D0    ; Position cursor
    MOVE.W  #$1B04,     D1     ; Col 27, Row 4
    TRAP    #15
    LEA     MENU_BANNER,A1    ; Address of banner string
    MOVE    #13,        D0     ; Task 13 = print null-terminated string
    TRAP    #15

    ; --- Game title (spaced letters for visual size) ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$1C05,     D1     ; Col 28, Row 5
    TRAP    #15
    LEA     MENU_TITLE, A1    ; "B A S K E T H O P P E R"
    MOVE    #13,        D0
    TRAP    #15

    ; --- Bottom banner ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$1B06,     D1     ; Col 27, Row 6
    TRAP    #15
    LEA     MENU_BANNER,A1
    MOVE    #13,        D0
    TRAP    #15

    ; --- Option 1: Play ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$2309,     D1     ; Col 35, Row 9
    TRAP    #15
    LEA     MENU_OPT1,  A1    ; "1  -  Play"
    MOVE    #13,        D0
    TRAP    #15

    ; --- Difficulty line (each full string has its own centered column) ---
    ; "Difficulty: Easy/Hard" = 16 chars -> col 32
    ; "Difficulty: Normal"    = 18 chars -> col 31
    MOVE.L  DIFFICULTY, D1    ; Load current difficulty value
    CMP.L   #DIFF_EASY, D1    ; Is it Easy?
    BEQ     SHOW_EASY          ; Yes -> show Easy string
    CMP.L   #DIFF_NORM, D1    ; Is it Normal?
    BEQ     SHOW_NORM          ; Yes -> show Normal string
    BRA     SHOW_HARD          ; Otherwise -> Hard

SHOW_EASY:
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$200B,     D1     ; Col 32, Row 11 (16-char string centered)
    TRAP    #15
    LEA     DIFF_EASY_LINE, A1 ; "Difficulty: Easy"
    MOVE    #13,        D0
    TRAP    #15
    BRA     AFTER_DIFF         ; Skip other difficulty branches

SHOW_NORM:
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$1F0B,     D1     ; Col 31, Row 11 (18-char string centered)
    TRAP    #15
    LEA     DIFF_NORM_LINE, A1 ; "Difficulty: Normal"
    MOVE    #13,        D0
    TRAP    #15
    BRA     AFTER_DIFF

SHOW_HARD:
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$200B,     D1     ; Col 32, Row 11 (16-char string centered)
    TRAP    #15
    LEA     DIFF_HARD_LINE, A1 ; "Difficulty: Hard"
    MOVE    #13,        D0
    TRAP    #15

AFTER_DIFF:
    ; --- Hint: press D to change difficulty ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$1E0C,     D1     ; Col 30, Row 12  (19 chars -> col 30)
    TRAP    #15
    LEA     MENU_DHELP, A1    ; "(press D to change)"
    MOVE    #13,        D0
    TRAP    #15

    ; --- Option 2: Quit ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$230E,     D1     ; Col 35, Row 14
    TRAP    #15
    LEA     MENU_OPT2,  A1    ; "2  -  Quit"
    MOVE    #13,        D0
    TRAP    #15

    ; Swap back buffer to front so all menu text becomes visible
    MOVE.B  #94,        D0     ; Task 94 = buffer swap
    TRAP    #15

MENU_WAIT:
    ; Task 5 = blocking character read - waits until a key is pressed.
    ; This avoids the polling loop missing keypresses that Task 19 suffers from.
    MOVE.B  #05,        D0     ; Task 5: wait for keypress, result in D1.B
    TRAP    #15
    CMP.B   #KEY_1,     D1    ; Was '1' pressed?
    BEQ     MENU_PLAY          ; Yes -> start game
    CMP.B   #KEY_2,     D1    ; Was '2' pressed?
    BEQ     EXIT               ; Yes -> quit
    CMP.B   #KEY_D,     D1    ; Was 'd' pressed?
    BEQ     CYCLE_DIFF         ; Yes -> cycle difficulty
    CMP.B   #KEY_D_U,   D1    ; Was 'D' pressed?
    BEQ     CYCLE_DIFF         ; Yes -> cycle difficulty
    CMP.B   #ESCAPE,    D1    ; Was ESC pressed?
    BEQ     EXIT               ; Yes -> quit
    BRA     MENU_WAIT          ; None matched -> keep waiting

MENU_PLAY:
    BSR     INIT_GAME          ; Set up all game state before entering loop
    BRA     GAME               ; Jump into the game loop

*===========================================================
* Subroutine    : CYCLE_DIFF
* Description   : Change difficulty Easy->Normal->Hard->Easy
*                 and redraws the main menu to reflect the change.
*===========================================================
CYCLE_DIFF:
    MOVE.L  DIFFICULTY, D1    ; Load current difficulty
    CMP.L   #DIFF_EASY, D1    ; Currently Easy?
    BEQ     GOTO_NORM          ; Yes -> switch to Normal
    CMP.L   #DIFF_NORM, D1    ; Currently Normal?
    BEQ     GOTO_HARD          ; Yes -> switch to Hard
    MOVE.L  #DIFF_EASY, DIFFICULTY ; Was Hard -> wrap back to Easy
    BRA     MAIN_MENU          ; Redraw menu with updated difficulty
GOTO_NORM:
    MOVE.L  #DIFF_NORM, DIFFICULTY ; Set Normal
    BRA     MAIN_MENU
GOTO_HARD:
    MOVE.L  #DIFF_HARD, DIFFICULTY ; Set Hard
    BRA     MAIN_MENU

*===========================================================
* Subroutine    : INIT_GAME
* Description   : Resets game state for a fresh run.
*                 Called at game start and on restart/reset.
*                 Also applies difficulty.
*===========================================================
INIT_GAME:
    ; --- Player starting X position: one quarter of screen width ---
    CLR.L   D1                 ; Clear D1 to zero-extend word load
    MOVE.W  SCREEN_W,   D1    ; D1 = screen width
    DIVU    #04,        D1    ; D1 = screen_w / 4
    MOVE.L  D1,         PLAYER_X ; Store as player X

    ; --- Player starting Y position: halfway down screen (ground level) ---
    CLR.L   D1
    MOVE.W  SCREEN_H,   D1    ; D1 = screen height
    DIVU    #02,        D1    ; D1 = screen_h / 2
    MOVE.L  D1,         PLAYER_Y ; Store as player Y (ground level)

    ; --- Reset player stats to maximum ---
    MOVE.L  #PLYR_MAX_HP, PLAYER_HP       ; Full health
    MOVE.L  #PLYR_MAX_ST, PLAYER_STAMINA  ; Full stamina

    ; --- Reset score and physics ---
    CLR.L   D1
    MOVE.L  D1,         PLAYER_SCORE   ; Score starts at 0
    MOVE.L  D1,         STAM_TICK      ; Stamina drain tick counter reset
    MOVE.L  #PLYR_DFLT_V, PLYR_VELOCITY ; No initial vertical movement
    MOVE.L  #PLYR_DFLT_G, PLYR_GRAVITY  ; Standard gravity
    MOVE.L  #GND_TRUE,  PLYR_ON_GND   ; Player starts on the ground

    ; --- Apply difficulty-specific values ---
    MOVE.L  DIFFICULTY, D1    ; Load chosen difficulty
    CMP.L   #DIFF_EASY, D1
    BEQ     APPLY_EASY
    CMP.L   #DIFF_NORM, D1
    BEQ     APPLY_NORM
    BRA     APPLY_HARD         ; Defaults to Hard if neither Easy nor Normal

APPLY_EASY:
    MOVE.L  #SPD_EASY,       CURR_BRICK_SPD ; Slow brick
    MOVE.L  #TICK_EASY,      STAM_RATE      ; Slow stamina drain
    MOVE.L  #HEAL_SPAWN_EASY, HEAL_SPAWN    ; Heal appears fairly often
    MOVE.L  #WATER_SPAWN_EASY,WATER_SPAWN   ; Water appears occasionally
    BRA     DIFF_DONE

APPLY_NORM:
    MOVE.L  #SPD_NORM,       CURR_BRICK_SPD
    MOVE.L  #TICK_NORM,      STAM_RATE
    MOVE.L  #HEAL_SPAWN_NORM, HEAL_SPAWN
    MOVE.L  #WATER_SPAWN_NORM,WATER_SPAWN
    BRA     DIFF_DONE

APPLY_HARD:
    MOVE.L  #SPD_HARD,       CURR_BRICK_SPD ; Fast brick
    MOVE.L  #TICK_HARD,      STAM_RATE      ; Very fast stamina drain
    MOVE.L  #HEAL_SPAWN_HARD, HEAL_SPAWN    ; Heal is rare
    MOVE.L  #WATER_SPAWN_HARD,WATER_SPAWN   ; Water is very rare

DIFF_DONE:
    ; --- Brick starting position: right edge of screen, at ground level ---
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1    ; Brick X starts at right edge
    MOVE.L  D1,         BRICK_X
    CLR.L   D1
    MOVE.W  SCREEN_H,   D1
    DIVU    #02,        D1    ; Brick Y = screen_h / 2 (ground)
    SUB.L   #10,        D1    ; Shift up slightly so brick sits on ground line
    MOVE.L  D1,         BRICK_Y

    ; --- Heal pickup: spawn off-screen right using difficulty offset ---
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    ADD.L   HEAL_SPAWN, D1    ; Offset beyond right edge for rarity
    MOVE.L  D1,         HEAL_X
    CLR.L   D1
    MOVE.W  SCREEN_H,   D1
    DIVU    #02,        D1    ; Heal floats at ground level
    MOVE.L  D1,         HEAL_Y

    ; --- Water pickup: spawn even further off-screen right ---
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    ADD.L   WATER_SPAWN,D1    ; Larger offset = rarer than heal
    MOVE.L  D1,         WATER_X
    CLR.L   D1
    MOVE.W  SCREEN_H,   D1
    DIVU    #02,        D1    ; Water also at ground level
    MOVE.L  D1,         WATER_Y

    ; --- Clear current key and screen before game starts ---
    CLR.L   D1
    MOVE.L  D1,         CURRENT_KEY ; No key held at game start
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$FF00,     D1    ; Clear full screen
    TRAP    #15

    RTS                        ; Return to caller (MENU_PLAY or RESTART)

*===========================================================
* Subroutine    : GAME
* Description   : Game entry point. Plays the run sound then
*                 falls into the main game loop.
*===========================================================
GAME:
    BSR     PLAY_RUN           ; Start looping run sound

GAMELOOP:
    BSR     INPUT              ; Read and process keyboard input
    BSR     UPDATE             ; Advance physics, score, stamina, items
    BSR     IS_PLAYER_ON_GND   ; Clamp player to ground if needed
    BSR     CHECK_COLLISIONS   ; Test brick, heal, water overlaps
    BSR     DRAW               ; Render full scene to back buffer then swap
    BSR     DELAY              ; 2ms sleep to pace the frame rate
    BRA     GAMELOOP           ; Repeat forever until game over or quit

*===========================================================
* Subroutine    : INPUT
* Description   : Non-blocking keycheck via Task 19.
*                 If a key is pressed its code is saved in D2
*                 and execution falls to PROCESS_INPUT.
*                 If no key pressed, returns immediately.
*===========================================================
INPUT:
    CLR.L   D1                 ; Clear D1 before keycheck
    MOVE.B  #TC_KEYCODE,D0    ; Task 19: non-blocking key poll
    TRAP    #15                ; D1.B = ASCII code or 0 if nothing pressed
    MOVE.B  D1,         D2    ; Save keycode into D2 for PROCESS_INPUT
    CMP.B   #00,        D2    ; Was the result 0 (no key)?
    BEQ     PROCESS_INPUT      ; Yes -> still process (will match IDLE)
    TRAP    #15                ; Fire Task 19 a second time to consume the key
    CMP.B   #$FF,       D1    ; $FF = special non-printable signal
    BEQ     PROCESS_INPUT      ; Treat as no useful key
    RTS                        ; A real key was just consumed, return

*===========================================================
* Subroutine    : PROCESS_INPUT
* Description   : Branches based on the key code stored in D2.
*===========================================================
PROCESS_INPUT:
    MOVE.L  D2,         CURRENT_KEY  ; Save key for HUD display

    CMP.L   #ESCAPE,    CURRENT_KEY  ; ESC = quit immediately
    BEQ     EXIT

    CMP.L   #SPACEBAR,  CURRENT_KEY  ; SPACE = try to jump
    BEQ     JUMP

    CMP.L   #RESTART_KEY,   CURRENT_KEY ; lowercase r = in-game reset
    BEQ     IN_GAME_RESET

    CMP.L   #RESTART_KEY_U, CURRENT_KEY ; uppercase R = in-game reset
    BEQ     IN_GAME_RESET

    BRA     IDLE               ; No relevant key -> play idle animation

IN_GAME_RESET:
    BSR     INIT_GAME          ; Re-initialise all state
    BRA     GAME               ; Restart the game loop

*===========================================================
* Subroutine    : UPDATE
* Description   : Advances the game state one frame:
*                 - Applies gravity to player
*                 - Increments survival score
*                 - Drains stamina on a timer
*                 - Moves brick and pickups left
*                 - Respawns items when they leave the screen
*===========================================================
UPDATE:
    ; --- Player vertical physics ---
    MOVE.L  PLYR_VELOCITY, D1  ; Load current upward/downward velocity
    MOVE.L  PLYR_GRAVITY,  D2  ; Load gravity constant
    ADD.L   D2,         D1    ; velocity += gravity (pulls player down each frame)
    MOVE.L  D1,         PLYR_VELOCITY ; Save updated velocity
    ADD.L   PLAYER_Y,   D1    ; new_y = old_y + velocity
    MOVE.L  D1,         PLAYER_Y     ; Commit new Y position

    ; --- Survival score: +1 every frame ---
    ADD.L   #01,        PLAYER_SCORE

    ; --- Stamina drain via tick counter ---
    ; STAM_TICK counts up each frame. When it reaches STAM_RATE,
    ; one stamina point is deducted and the counter resets.
    MOVE.L  STAM_TICK,  D1    ; Load current tick count
    ADD.L   #01,        D1    ; Increment tick
    MOVE.L  D1,         STAM_TICK ; Save incremented tick
    MOVE.L  STAM_RATE,  D2    ; Load the threshold for this difficulty
    CMP.L   D2,         D1    ; Has tick reached the threshold?
    BLT     STAM_SKIP          ; No -> stamina unchanged this frame

    CLR.L   D1
    MOVE.L  D1,         STAM_TICK      ; Reset tick counter to 0
    MOVE.L  PLAYER_STAMINA, D1        ; Load stamina
    SUB.L   #01,        D1            ; Deduct 1 stamina point
    CMP.L   #00,        D1            ; Is stamina now zero or below?
    BLE     STAM_GONE          ; Yes -> trigger game over
    MOVE.L  D1,         PLAYER_STAMINA ; Save reduced stamina
    BRA     STAM_SKIP

STAM_GONE:
    MOVE.L  #00,        PLAYER_STAMINA ; Clamp stamina to 0 before game over
    BRA     GAME_OVER          ; Stamina empty = lose

STAM_SKIP:
    ; --- Move brick left each frame ---
    MOVE.L  BRICK_X,    D1    ; Load brick X
    CMP.L   #00,        D1    ; Has brick passed the left edge?
    BLE     RESET_BRICK        ; Yes -> reset to right edge
    MOVE.L  CURR_BRICK_SPD, D2 ; Load speed set by difficulty
    SUB.L   D2,         BRICK_X ; Move brick left
    BRA     DO_HEAL

RESET_BRICK:
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1    ; Respawn brick at right edge of screen
    MOVE.L  D1,         BRICK_X

DO_HEAL:
    ; --- Move health pickup left ---
    MOVE.L  HEAL_X,     D1
    CMP.L   #00,        D1    ; Has heal left the screen?
    BLE     RESET_HEAL
    SUB.L   #HEAL_SPD,  HEAL_X ; Move heal left by its fixed speed
    BRA     DO_WATER

RESET_HEAL:
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    ADD.L   HEAL_SPAWN, D1    ; Respawn far right using difficulty rarity offset
    MOVE.L  D1,         HEAL_X

DO_WATER:
    ; --- Move water pickup left ---
    MOVE.L  WATER_X,    D1
    CMP.L   #00,        D1    ; Has water left the screen?
    BLE     RESET_WATER
    SUB.L   #WATER_SPD, WATER_X ; Move water left by its fixed speed
    RTS                        ; End of UPDATE

RESET_WATER:
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    ADD.L   WATER_SPAWN,D1    ; Respawn far right using difficulty rarity offset
    MOVE.L  D1,         WATER_X
    RTS

*===========================================================
* Subroutine    : IS_PLAYER_ON_GND
* Description   : Checks if the player's Y has reached or
*                 passed the ground line (screen_h / 2).
*                 If so, brings them to ground and zeroes velocity.
*===========================================================
IS_PLAYER_ON_GND:
    CLR.L   D1
    CLR.L   D2
    MOVE.W  SCREEN_H,   D1    ; D1 = screen height
    DIVU    #02,        D1    ; D1 = ground Y = screen_h / 2
    MOVE.L  PLAYER_Y,   D2    ; D2 = current player Y
    CMP     D1,         D2    ; Is player Y >= ground Y?
    BGE     SET_ON_GROUND      ; Yes -> land
    BLT     SET_OFF_GROUND     ; No  -> still in the air
    RTS

SET_ON_GROUND:
    CLR.L   D1
    MOVE.W  SCREEN_H,   D1
    DIVU    #02,        D1    ; Recalculate ground Y
    MOVE.L  D1,         PLAYER_Y   ; Snap Y exactly to ground
    MOVE.L  #00,        PLYR_VELOCITY ; Kill downward velocity on landing
    MOVE.L  #GND_TRUE,  PLYR_ON_GND  ; Mark player as grounded
    RTS

SET_OFF_GROUND:
    MOVE.L  #GND_FALSE, PLYR_ON_GND  ; Mark player as airborne
    RTS

*===========================================================
* Subroutine    : JUMP
* Description   : Applies jump velocity if the player is
*                 currently on the ground. Ignores the input
*                 if the player is already airborne.
*===========================================================
JUMP:
    CMP.L   #GND_TRUE,  PLYR_ON_GND  ; Is player grounded?
    BEQ     PERFORM_JUMP               ; Yes -> allow jump
    BRA     JUMP_DONE                  ; No  -> ignore (no double-jump)
PERFORM_JUMP:
    BSR     PLAY_JUMP              ; Play jump sound effect
    MOVE.L  #PLYR_JUMP_V, PLYR_VELOCITY ; Apply upward velocity
    RTS
JUMP_DONE:
    RTS

*===========================================================
* Subroutine    : IDLE
* Description   : Called when no directional key is pressed.
*                 Plays the running animation/sound.
*===========================================================
IDLE:
    BSR     PLAY_RUN           ; Keep running animation active
    RTS

*===========================================================
* Subroutine    : DELAY
* Description   : Pauses 2 milliseconds per frame to pace
*                 the game loop at a stable speed.
*===========================================================
DELAY:
    MOVE.W  #2,         D1    ; 2 ms sleep duration
    MOVE.B  #TC_DELAY,  D0    ; Task 23 = sleep
    TRAP    #15
    RTS

RUN_LOAD:
    MOVE    #71,        D0     ; Task 71 = load sound
    TRAP    #15
    RTS

PLAY_RUN:
    MOVE    #72,        D0     ; Task 72 = play loaded sound
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
    MOVE    #72,        D0     ; Play collision/oops sound
    TRAP    #15
    RTS

*===========================================================
* Subroutine    : DRAW
* Description   : Full scene render called every frame.
*                 1) Swap buffers (moves last frame to screen)
*                 2) Clear back buffer with blank screen
*                 3) Draw all game objects into back buffer
*                 The swap at the start means the player sees
*                 the previous complete frame while the new
*                 one is being drawn - no flicker.
*===========================================================
DRAW:
    MOVE.B  #94,        D0    ; Task 94 = swap front/back buffers
    TRAP    #15                ; Displays the previously drawn frame
    MOVE.B  #TC_CURSR_P,D0   ; Now clear the back buffer for drawing
    MOVE.W  #$FF00,     D1    ; $FF00 = clear whole screen
    TRAP    #15
    BSR     DRAW_PLAYER        ; Draw orange player rectangle
    BSR     DRAW_BRICK         ; Draw brown obstacle rectangle
    BSR     DRAW_HEALER        ; Draw green health pickup rectangle
    BSR     DRAW_WATER         ; Draw blue stamina pickup rectangle
    BSR     DRAW_HUD           ; Draw score / health / stamina text
    RTS

*===========================================================
* Subroutine    : DRAW_HUD
* Description   : Prints score, health, stamina and control
*                 hints as text in the top-left corner.
*                 Uses Task 13 for strings and Task 3 for numbers.
*===========================================================
DRAW_HUD:
    ; Set pen and fill to black so text background is correct
    MOVE.L  #BLACK,     D1
    MOVE.B  #80,        D0    ; Task 80 = set pen (outline) colour
    TRAP    #15
    MOVE.L  #BLACK,     D1
    MOVE.B  #81,        D0    ; Task 81 = set fill colour
    TRAP    #15

    ; --- Score label at col 2, row 1 ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$0201,     D1    ; Col 2, Row 1
    TRAP    #15
    LEA     SCORE_MSG,  A1    ; "Score  : "
    MOVE    #13,        D0
    TRAP    #15
    ; --- Score value at col 9, row 1 ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$0901,     D1    ; Col 9, Row 1
    TRAP    #15
    MOVE.B  #03,        D0    ; Task 3 = print unsigned long in D1
    MOVE.L  PLAYER_SCORE, D1
    TRAP    #15

    ; --- Health label at col 2, row 2 ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$0202,     D1
    TRAP    #15
    LEA     HEALTH_MSG, A1    ; "Health : "
    MOVE    #13,        D0
    TRAP    #15
    ; --- Health value at col 11, row 2 ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$0B02,     D1
    TRAP    #15
    MOVE.B  #03,        D0
    MOVE.L  PLAYER_HP,  D1
    TRAP    #15

    ; --- Stamina label at col 2, row 3 ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$0203,     D1
    TRAP    #15
    LEA     STAMINA_MSG,A1    ; "Stamina: "
    MOVE    #13,        D0
    TRAP    #15
    ; --- Stamina value at col 11, row 3 ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$0B03,     D1
    TRAP    #15
    MOVE.B  #03,        D0
    MOVE.L  PLAYER_STAMINA, D1
    TRAP    #15

    ; --- Controls hint at col 2, row 4 ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$0204,     D1
    TRAP    #15
    LEA     HINT_MSG,   A1    ; "SPACE=Jump  R=Reset  ESC=Quit"
    MOVE    #13,        D0
    TRAP    #15

    RTS

*===========================================================
* Subroutine    : DRAW_PLAYER
* Description   : Draws the player as an orange filled ellipse.
*                 Task 88 draws ellipse with top-left (D1,D2)
*                 and bottom-right (D3,D4) bounding box.
*===========================================================
DRAW_PLAYER:
    MOVE.L  #ORANGE,    D1    ; Set pen colour to orange
    MOVE.B  #80,        D0
    TRAP    #15
    MOVE.L  #ORANGE,    D1    ; Set fill colour to orange
    MOVE.B  #81,        D0
    TRAP    #15
    MOVE.L  PLAYER_X,   D1   ; Left edge   = player X
    MOVE.L  PLAYER_Y,   D2   ; Top edge    = player Y
    MOVE.L  PLAYER_X,   D3
    ADD.L   #PLYR_W_INIT, D3  ; Right edge  = player X + width
    MOVE.L  PLAYER_Y,   D4
    ADD.L   #PLYR_H_INIT, D4  ; Bottom edge = player Y + height
    MOVE.B  #88,        D0   ; Task 88 = draw filled ellipse
    TRAP    #15
    RTS

*===========================================================
* Subroutine    : DRAW_BRICK
* Description   : Draws the obstacle as a brown filled rectangle.
*                 Task 87 draws filled rectangle (D1,D2)-(D3,D4).
*===========================================================
DRAW_BRICK:
    MOVE.L  #BROWN,     D1   ; Set pen colour to brown
    MOVE.B  #80,        D0
    TRAP    #15
    MOVE.L  #BROWN,     D1   ; Set fill colour to brown
    MOVE.B  #81,        D0
    TRAP    #15
    MOVE.L  BRICK_X,    D1   ; Left edge
    MOVE.L  BRICK_Y,    D2   ; Top edge
    MOVE.L  BRICK_X,    D3
    ADD.L   #BRICK_W,   D3   ; Right edge = X + width
    MOVE.L  BRICK_Y,    D4
    ADD.L   #BRICK_H,   D4   ; Bottom edge = Y + height
    MOVE.B  #87,        D0   ; Task 87 = draw filled rectangle
    TRAP    #15
    RTS

*===========================================================
* Subroutine    : DRAW_HEALER
* Description   : Draws the health pickup as a green rectangle.
*===========================================================
DRAW_HEALER:
    MOVE.L  #GREEN,     D1   ; Set pen colour to green
    MOVE.B  #80,        D0
    TRAP    #15
    MOVE.L  #GREEN,     D1   ; Set fill colour to green
    MOVE.B  #81,        D0
    TRAP    #15
    MOVE.L  HEAL_X,     D1   ; Left edge
    MOVE.L  HEAL_Y,     D2   ; Top edge
    MOVE.L  HEAL_X,     D3
    ADD.L   #HEAL_W,    D3   ; Right edge
    MOVE.L  HEAL_Y,     D4
    ADD.L   #HEAL_H,    D4   ; Bottom edge
    MOVE.B  #87,        D0   ; Draw filled rectangle
    TRAP    #15
    RTS

*===========================================================
* Subroutine    : DRAW_WATER
* Description   : Draws the stamina pickup as a blue rectangle.
*===========================================================
DRAW_WATER:
    MOVE.L  #BLUE,      D1   ; Set pen colour to blue
    MOVE.B  #80,        D0
    TRAP    #15
    MOVE.L  #BLUE,      D1   ; Set fill colour to blue
    MOVE.B  #81,        D0
    TRAP    #15
    MOVE.L  WATER_X,    D1   ; Left edge
    MOVE.L  WATER_Y,    D2   ; Top edge
    MOVE.L  WATER_X,    D3
    ADD.L   #WATER_W,   D3   ; Right edge
    MOVE.L  WATER_Y,    D4
    ADD.L   #WATER_H,   D4   ; Bottom edge
    MOVE.B  #87,        D0   ; Draw filled rectangle
    TRAP    #15
    RTS

*===========================================================
* Subroutine    : CHECK_COLLISIONS
* Description   : Dispatcher that calls all three collision
*                 checks in sequence each frame.
*===========================================================
CHECK_COLLISIONS:
    BSR     CHECK_BRICK_COL   ; Check player vs obstacle
    BSR     CHECK_HEAL_COL    ; Check player vs health pickup
    BSR     CHECK_WATER_COL   ; Check player vs water pickup
    RTS

*===========================================================
* Subroutine    : CHECK_BRICK_COL
* Description   : Collision
*                 between the player and the brick obstacle.
*                 Four separate overlap tests - if all four
*                 pass then the rectangles are overlapping.
*                 On hit: deduct damage; if HP <= 0 game over;
*                 otherwise teleport brick back to right edge.
*===========================================================
CHECK_BRICK_COL:
    CLR.L   D1
    CLR.L   D2

    ; Test 1: Is player LEFT edge to the right of brick's RIGHT edge?
    MOVE.L  PLAYER_X,   D1
    MOVE.L  BRICK_X,    D2
    ADD.L   #BRICK_W,   D2    ; D2 = brick right edge
    CMP.L   D2,         D1    ; player_x >= brick_right?
    BGE     BRICK_NO_HIT       ; Yes -> player is fully to the right, no hit

    ; Test 2: Is player RIGHT edge to the left of brick's LEFT edge?
    MOVE.L  PLAYER_X,   D1
    ADD.L   #PLYR_W_INIT, D1  ; D1 = player right edge
    MOVE.L  BRICK_X,    D2
    CMP.L   D2,         D1    ; player_right <= brick_x?
    BLE     BRICK_NO_HIT       ; Yes -> player is fully to the left, no hit

    ; Test 3: Is player TOP edge below brick's BOTTOM edge?
    MOVE.L  PLAYER_Y,   D1
    MOVE.L  BRICK_Y,    D2
    ADD.L   #BRICK_H,   D2    ; D2 = brick bottom edge
    CMP.L   D2,         D1    ; player_y >= brick_bottom?
    BGE     BRICK_NO_HIT       ; Yes -> player is below brick, no hit

    ; Test 4: Is player BOTTOM edge above brick's TOP edge?
    MOVE.L  PLAYER_Y,   D1
    ADD.L   #PLYR_H_INIT, D1  ; D1 = player bottom edge
    MOVE.L  BRICK_Y,    D2
    CMP.L   D2,         D1    ; player_bottom <= brick_y?
    BLE     BRICK_NO_HIT       ; Yes -> player is above brick, no hit

    BRA     BRICK_HIT          ; All four tests passed -> collision!

BRICK_NO_HIT:
    RTS                        ; No overlap, return normally

BRICK_HIT:
    MOVE.L  PLAYER_HP,  D1    ; Load current health
    SUB.L   #BRICK_DMG, D1    ; Subtract collision damage
    CMP.L   #00,        D1    ; Is health now zero or below?
    BLE     GAME_OVER          ; Yes -> player is dead
    MOVE.L  D1,         PLAYER_HP ; Save reduced health
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1    ; Respawn brick at right edge after hit
    MOVE.L  D1,         BRICK_X
    RTS

*===========================================================
* Subroutine    : CHECK_HEAL_COL
* Description   : Collision between player and the green
*                 health pickup. On pickup: add HEAL_AMT to HP
*                 (capped at max), then respawn pickup.
*===========================================================
CHECK_HEAL_COL:
    CLR.L   D1
    CLR.L   D2

    ; Test 1: player left >= heal right?
    MOVE.L  PLAYER_X,   D1
    MOVE.L  HEAL_X,     D2
    ADD.L   #HEAL_W,    D2
    CMP.L   D2,         D1
    BGE     HEAL_NO_HIT

    ; Test 2: player right <= heal left?
    MOVE.L  PLAYER_X,   D1
    ADD.L   #PLYR_W_INIT, D1
    MOVE.L  HEAL_X,     D2
    CMP.L   D2,         D1
    BLE     HEAL_NO_HIT

    ; Test 3: player top >= heal bottom?
    MOVE.L  PLAYER_Y,   D1
    MOVE.L  HEAL_Y,     D2
    ADD.L   #HEAL_H,    D2
    CMP.L   D2,         D1
    BGE     HEAL_NO_HIT

    ; Test 4: player bottom <= heal top?
    MOVE.L  PLAYER_Y,   D1
    ADD.L   #PLYR_H_INIT, D1
    MOVE.L  HEAL_Y,     D2
    CMP.L   D2,         D1
    BLE     HEAL_NO_HIT

    BRA     HEAL_PICKUP        ; All four pass -> collect it

HEAL_NO_HIT:
    RTS

HEAL_PICKUP:
    MOVE.L  PLAYER_HP,  D1    ; Load current health
    ADD.L   #HEAL_AMT,  D1    ; Add heal amount
    CMP.L   #PLYR_MAX_HP, D1  ; Would it exceed the maximum?
    BLE     SET_HEAL_HP        ; No  -> use the increased value
    MOVE.L  #PLYR_MAX_HP, D1  ; Yes -> cap at max
SET_HEAL_HP:
    MOVE.L  D1,         PLAYER_HP  ; Save updated health
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    ADD.L   HEAL_SPAWN, D1    ; Respawn heal far off-screen right
    MOVE.L  D1,         HEAL_X
    RTS

*===========================================================
* Subroutine    : CHECK_WATER_COL
* Description   : Collision between player and the blue
*                 water pickup. On pickup: add WATER_AMT to
*                 stamina (capped at max), then respawn.
*===========================================================
CHECK_WATER_COL:
    CLR.L   D1
    CLR.L   D2

    ; Test 1: player left >= water right?
    MOVE.L  PLAYER_X,   D1
    MOVE.L  WATER_X,    D2
    ADD.L   #WATER_W,   D2
    CMP.L   D2,         D1
    BGE     WATER_NO_HIT

    ; Test 2: player right <= water left?
    MOVE.L  PLAYER_X,   D1
    ADD.L   #PLYR_W_INIT, D1
    MOVE.L  WATER_X,    D2
    CMP.L   D2,         D1
    BLE     WATER_NO_HIT

    ; Test 3: player top >= water bottom?
    MOVE.L  PLAYER_Y,   D1
    MOVE.L  WATER_Y,    D2
    ADD.L   #WATER_H,   D2
    CMP.L   D2,         D1
    BGE     WATER_NO_HIT

    ; Test 4: player bottom <= water top?
    MOVE.L  PLAYER_Y,   D1
    ADD.L   #PLYR_H_INIT, D1
    MOVE.L  WATER_Y,    D2
    CMP.L   D2,         D1
    BLE     WATER_NO_HIT

    BRA     WATER_PICKUP       ; All four pass -> collect it

WATER_NO_HIT:
    RTS

WATER_PICKUP:
    MOVE.L  PLAYER_STAMINA, D1 ; Load current stamina
    ADD.L   #WATER_AMT, D1    ; Restore WATER_AMT stamina
    CMP.L   #PLYR_MAX_ST, D1  ; Would it exceed the maximum?
    BLE     SET_WATER_ST       ; No  -> use increased value
    MOVE.L  #PLYR_MAX_ST, D1  ; Yes -> cap at max
SET_WATER_ST:
    MOVE.L  D1,         PLAYER_STAMINA ; Save updated stamina
    CLR.L   D1
    MOVE.W  SCREEN_W,   D1
    ADD.L   WATER_SPAWN,D1    ; Respawn water far off-screen right
    MOVE.L  D1,         WATER_X
    RTS

*===========================================================
* Subroutine    : GAME_OVER
* Description   : Triggered when HP or stamina hits zero.
*                 Clears screen and shows plain-text result:
*                   "Hard luck!"
*                   "Your Score:"
*                   <score value>
*                   "R  -  Restart"
*                   "M  -  Main Menu"
*                 Waits for R/M/ESC via blocking Task 5.
*
* Column centering maths (80-col screen):
*   "Hard luck!"      10 chars -> col (80-10)/2 = 35 ($23)
*   "Your Score:"     11 chars -> col (80-11)/2 = 34 ($22)
*   score number               -> col 38 ($26) (approx centre for 4 digits)
*   "R  -  Restart"   13 chars -> col (80-13)/2 = 33 ($21)
*   "M  -  Main Menu" 15 chars -> col (80-15)/2 = 32 ($20)
*===========================================================
GAME_OVER:
    MOVE.L  #00,        PLAYER_HP  ; Ensure HP is zeroed for display

    MOVE.B  #TC_CURSR_P,D0    ; Clear screen for game over layout
    MOVE.W  #$FF00,     D1
    TRAP    #15

    ; --- "Hard luck!" centred, row 8 ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$2308,     D1     ; Col 35, Row 8
    TRAP    #15
    LEA     DEFEAT_HDR, A1
    MOVE    #13,        D0
    TRAP    #15

    ; --- "Your Score:" centred, row 10 ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$220A,     D1     ; Col 34, Row 10
    TRAP    #15
    LEA     FINALSCORE_MSG, A1
    MOVE    #13,        D0
    TRAP    #15

    ; --- Score number on its own row 11, approx centred ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$260B,     D1     ; Col 38, Row 11
    TRAP    #15
    MOVE.B  #03,        D0    ; Task 3 = print unsigned integer from D1
    MOVE.L  PLAYER_SCORE, D1
    TRAP    #15

    ; --- "R  -  Restart" centred, row 13 ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$210D,     D1     ; Col 33, Row 13
    TRAP    #15
    LEA     RETRY_MSG,  A1
    MOVE    #13,        D0
    TRAP    #15

    ; --- "M  -  Main Menu" centred, row 15 ---
    MOVE.B  #TC_CURSR_P,D0
    MOVE.W  #$200F,     D1     ; Col 32, Row 15
    TRAP    #15
    LEA     MENU_MSG,   A1
    MOVE    #13,        D0
    TRAP    #15

    ; Swap buffer so game over text becomes visible
    MOVE.B  #94,        D0
    TRAP    #15

DEFEAT_WAIT:
    ; Task 5 = blocking read - waits until a key is pressed
    MOVE.B  #05,        D0
    TRAP    #15
    CMP.B   #RESTART_KEY,   D1 ; Lowercase r = restart
    BEQ     RESTART
    CMP.B   #RESTART_KEY_U, D1 ; Uppercase R = restart
    BEQ     RESTART
    CMP.B   #MENU_KEY,      D1 ; Lowercase m = main menu
    BEQ     GOTO_MENU
    CMP.B   #MENU_KEY_U,    D1 ; Uppercase M = main menu
    BEQ     GOTO_MENU
    CMP.B   #ESCAPE,        D1 ; ESC = quit program
    BEQ     EXIT
    BRA     DEFEAT_WAIT        ; Unrecognised key -> keep waiting

GOTO_MENU:
    BRA     MAIN_MENU          ; Return to title screen

*===========================================================
* Subroutine    : RESTART
* Description   : Resets all game state and re-enters the
*                 game loop without changing difficulty.
*===========================================================
RESTART:
    BSR     INIT_GAME          ; Full state reset
    BRA     GAME               ; Back to game loop

*===========================================================
* Subroutine    : EXIT
* Description   : Prints exit message, then terminates via
*                 Task 9 and halts the simulator.
*===========================================================
EXIT:
    MOVE.B  #TC_CURSR_P,D0   ; Position cursor for exit message
    MOVE.W  #$4004,     D1    ; Col 64, Row 4
    TRAP    #15
    LEA     EXIT_MSG,   A1   ; "Exiting..."
    MOVE    #13,        D0
    TRAP    #15
    MOVE.B  #TC_EXIT,   D0   ; Task 9 = terminate program
    TRAP    #15
    SIMHALT                   ; Halt simulator as a safety fallback

*===========================================================
* Section       : String Data
* Description   : Null-terminated strings used for HUD,
*                 menus and game over screen.
*===========================================================

; --- In-game HUD labels ---
SCORE_MSG       DC.B    'Score  : ', 0    ; Printed next to score value
HEALTH_MSG      DC.B    'Health : ', 0    ; Printed next to health value
STAMINA_MSG     DC.B    'Stamina: ', 0    ; Printed next to stamina value
HINT_MSG        DC.B    'SPACE=Jump  R=Reset  ESC=Quit', 0 ; Control reminder
EXIT_MSG        DC.B    'Exiting...', 0   ; Shown on program exit

; --- Main menu strings ---
MENU_BANNER     DC.B    '=========================', 0  ; Decorative border
MENU_TITLE      DC.B    'B A S K E T H O P P E R', 0   ; Spaced title
MENU_OPT1       DC.B    '1  -  Play', 0                 ; Start game option
MENU_DHELP      DC.B    '(press D to change)', 0        ; Difficulty hint
MENU_OPT2       DC.B    '2  -  Quit', 0                 ; Exit option

; --- Difficulty display strings (full line, each centred individually) ---
DIFF_EASY_LINE  DC.B    'Difficulty: Easy', 0    ; 16 chars
DIFF_NORM_LINE  DC.B    'Difficulty: Normal', 0  ; 18 chars
DIFF_HARD_LINE  DC.B    'Difficulty: Hard', 0    ; 16 chars

; --- Game over strings ---
DEFEAT_HDR      DC.B    'Hard luck!', 0           ; Main game over message
FINALSCORE_MSG  DC.B    'Your Score:', 0           ; Score label
RETRY_MSG       DC.B    'R  -  Restart', 0         ; Restart prompt
MENU_MSG        DC.B    'M  -  Main Menu', 0       ; Return to menu prompt

*===========================================================
* Section       : Colour Constants
* Description   : Set colors
*===========================================================
BLACK           EQU     $00000000   ; Background colour
ORANGE          EQU     $00008CFF   ; Player basketball colour (BGR orange)
GREEN           EQU     $0000FF00   ; Health pickup colour
BROWN           EQU     $0013458B   ; Brick obstacle colour
BLUE            EQU     $00FF0000   ; Water/stamina pickup colour

*===========================================================
* Section       : Variable Storage
* Description   : All runtime variables. DS.W/DS.L reserve
*                 word/long-word storage without initialising.
*===========================================================

; --- Screen dimensions (filled in by INITIALISE) ---
SCREEN_W        DS.W    01          ; Screen width  in pixels
SCREEN_H        DS.W    01          ; Screen height in pixels

; --- Input state ---
CURRENT_KEY     DS.L    01          ; Most recent ASCII keycode (for HUD display)

; --- Difficulty runtime state ---
DIFFICULTY      DS.L    01          ; Currently selected difficulty (1/2/3)
CURR_BRICK_SPD  DS.L    01          ; Brick speed in px/frame (set from difficulty)
STAM_RATE       DS.L    01          ; Frames between each 1-point stamina drain
STAM_TICK       DS.L    01          ; Current frame counter toward next drain event
HEAL_SPAWN      DS.L    01          ; Pixels beyond screen-right that heal spawns at
WATER_SPAWN     DS.L    01          ; Pixels beyond screen-right that water spawns at

; --- Player state ---
PLAYER_X        DS.L    01          ; Player horizontal position (pixels from left)
PLAYER_Y        DS.L    01          ; Player vertical position   (pixels from top)
PLAYER_HP       DS.L    01          ; Current health (0-100)
PLAYER_STAMINA  DS.L    01          ; Current stamina (0-100)
PLAYER_SCORE    DS.L    01          ; Survival score (increments every frame)
PLYR_VELOCITY   DS.L    01          ; Vertical velocity (negative = moving up)
PLYR_GRAVITY    DS.L    01          ; Gravity constant added to velocity each frame
PLYR_ON_GND     DS.L    01          ; 1 if player is on the ground, 0 if airborne

; --- Brick obstacle state ---
BRICK_X         DS.L    01          ; Brick horizontal position
BRICK_Y         DS.L    01          ; Brick vertical position (fixed at ground level)

; --- Green health pickup state ---
HEAL_X          DS.L    01          ; Heal pickup horizontal position
HEAL_Y          DS.L    01          ; Heal pickup vertical position

; --- Blue water/stamina pickup state ---
WATER_X         DS.L    01          ; Water pickup horizontal position
WATER_Y         DS.L    01          ; Water pickup vertical position

    END    START               ; Program entry point is START label


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
