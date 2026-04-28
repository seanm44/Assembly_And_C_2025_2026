# Project 2 Convert 68000 Assembly Code to x86_64

Name: Sean Maher

Student Number: C00310393

What Is Included

System Calls — TRAP #15 replaced with printf and scanf from C.
Registers — 68000 data registers D1-D4 mapped to x86_64 equivalents.
Calling Convention — Parameters previously passed via D1/D2 are now passed via rdi/rsi with the result returned in rax.
Stack Alignment — sub rsp, 16 added before calls to maintain 16-byte alignment.

Security Fixes
Integer Overflow — jo HANDLE_OVERFLOW added to catch signed overflow that the original left unchecked.
Input Validation — A 1000000 limit check added after each addition.
Stack Management — Proper push rbp / leave / ret used in all subroutines.
