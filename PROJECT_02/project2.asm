; -----------------------------------------------------------------------------
; Student Number: C00310393
; Name: Sean Maher
; -----------------------------------------------------------------------------

extern printf, scanf, exit           ; Import C functions for I/O and exit

section .data
    PROMPT:       db 'Enter number: ', 0       ; String to ask user for input
    RESULT:       db 'The sum is: %ld', 10, 0   ; String to show current addition
    FINAL_RESULT: db 'The Final sum is: %ld', 10, 0 ; String for the total
    CRLF:         db 10, 0                     ; Newline character 
    FMT_IN:       db '%ld', 0                  ; Format for scanf 
    MAX_LIMIT:    dq 1000000                   ; Max set to 1,000,000
    ERR_OFLOW:    db 'Error: Number too big!', 10, 0 ; Error Message

section .text
    global main                      ; Make main visible to the linker

main:
    push rbp                         ; Save old base pointer
    mov rbp, rsp                     ; Set up new stack frame
    
    xor rbx, rbx                     ; CLR.L D3 (Set sum to 0)
    mov r12, 3                       ; MOVE.W #3, D4 , Set loop to 3 

GAME_LOOP:
    ; --- Input Number 1 ---
    mov rdi, PROMPT                  ; Load address of prompt string
    xor rax, rax                     ; printf needs rax=0 for non-vector args
    call printf                      ; Display 'Enter number: '

    sub rsp, 16                      ; Align stack and makes room for input
    mov rdi, FMT_IN                  ; Load format string "%ld"
    mov rsi, rsp                     ; Tell scanf to put data on top of stack
    call scanf                       ; User input
    mov r13, [rsp]                   ; MOVE.L D1, D2 , Grab input from stack
    add rsp, 16                      ; Restore stack pointer

    ; --- Input Number 2 ---
    mov rdi, PROMPT                  ; Load address of prompt string
    xor rax, rax                     ; Clear rax for printf
    call printf                      ; Display 'Enter number: '

    sub rsp, 16                      ; Make room for second input
    mov rdi, FMT_IN                  ; Load format string "%ld"
    mov rsi, rsp                     ; Store input at [rsp]
    call scanf                       ; Get user input
    mov rdi, [rsp]                   ; Load input into rdi
    add rsp, 16                      ; Restore stack pointer

    ; --- Subroutine Call ---
    mov rsi, r13                     ; Pass r13 (D2) as second parameter
    call REGISTER_ADDER              ; BSR REGISTER_ADDER
    
    ; --- Limit Check ---
    cmp rax, [MAX_LIMIT]             ; Check if current sum is > 1000000
    jg HANDLE_OVERFLOW               ; If bigger, jump to error handler

    ; --- Add to Running Sum & Check Overflow ---
    add rbx, rax                     ; ADD.L D1, D3 , Update running total
    jo  HANDLE_OVERFLOW              ; Hardware check for negative wrap-around
    cmp rbx, [MAX_LIMIT]             ; Check if total sum > 1000000
    jg HANDLE_OVERFLOW               ; If total too big, jump to error

    ; --- Display Intermediate Result ---
    mov rdi, RESULT                  ; Load 'The sum is: ' string
    mov rsi, rax                     ; Move current sum to second argument
    xor rax, rax                     ; Clear rax for printf
    call printf                      ; Display current sum

    call NEW_LINE                    ; BSR NEW_LINE , Print a newline
    dec r12                          ; SUBQ.W #1, D4 , Counter - 1
    jnz GAME_LOOP                    ; BNE GAME_LOOP , Repeat if not zero

    ; --- Final Output ---
    mov rdi, FINAL_RESULT            ; Load 'The Final sum is: ' string
    mov rsi, rbx                     ; Move total sum to second argument
    xor rax, rax                     ; Clear rax for printf
    call printf                      ; Display total sum

    mov rax, 0                       ; Return 0 to OS
    leave                            ; Undo stack frame setup
    ret                              ; Exit program

; --- Error Handler ---
HANDLE_OVERFLOW:
    mov rdi, ERR_OFLOW               ; Load error message string
    xor rax, rax                     ; Clear rax for printf
    call printf                      ; Print the error
    mov rdi, 1                       ; Return error code 1
    call exit                        ; Stop program

; Subroutine: REGISTER_ADDER 
REGISTER_ADDER:
    mov rax, rdi                     ; Move first param to rax
    add rax, rsi                     ; ADD.L D2, D1
    jo HANDLE_OVERFLOW               ; Security: Check for overflow during add
    ret                              ; RTS

; Subroutine: NEW_LINE
NEW_LINE:
    mov rdi, CRLF                    ; Load newline character string
    xor rax, rax                     ; Clear rax for printf
    call printf                      ; Display the newline
    ret                              ; RTS 

; Security metadata to ensure the stack is non-executable
section .note.GNU-stack noalloc noexec nowrite progbits