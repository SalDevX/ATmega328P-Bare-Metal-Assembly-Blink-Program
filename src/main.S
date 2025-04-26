;================================================================================
; ATmega328P Bare-Metal Assembly Blink Program
;================================================================================
; Registers and Memory Architecture:
; - 8-bit AVR RISC architecture
; - 32 general-purpose registers (R0-R31)
; - 16-bit Program Counter (PC)
; - Separate Harvard architecture (flash for code, SRAM for data)
; - 16MHz clock (Arduino Uno default)
;--------------------------------------------------------------------------------

;--- Special Function Register (SFR) Configuration ---------------------------------
#define __SFR_OFFSET 0
; Use actual I/O addresses (0x00-0x3F) instead of offset

#include <avr/io.h>
; Include I/O definitions (DDRB, PORTB, etc.)

;--- Reset Vector Handling ---------------------------------------------------------
.section .init0        ; First code section executed after power-on/reset
.global main           ; Export main symbol for linker visibility
  jmp main             ; Jump to our main program, bypassing Arduino initialization

;--- Program Code Section ----------------------------------------------------------
.section .text         ; Where executable code resides in flash memory

;--- Main Program Entry Point ------------------------------------------------------
main:
  ; Stack Pointer Initialization (Critical for function calls/interrupts)
  ; ATmega328P has 2KB SRAM (0x0100-0x08FF), RAMEND = 0x08FF
  ldi r16, hi8(RAMEND) ; Load high byte of SRAM end address (0x08)
  out SPH, r16         ; Store in Stack Pointer High (SPH = 0x3E)
  ldi r16, lo8(RAMEND) ; Load low byte of SRAM end address (0xFF)
  out SPL, r16         ; Store in Stack Pointer Low (SPL = 0x3D)

  ; GPIO Configuration (Port B, Pin 5 - Arduino D13)
  ; DDRB: Data Direction Register B (0x24)
  ; PB5: Bit 5 controls I/O direction (1 = output, 0 = input)
  sbi DDRB, PB5        ; Set PB5 as output (DDRB |= (1 << 5))

;--- Main Execution Loop ----------------------------------------------------------
loop:
  ; LED Control Sequence:
  ; PORTB: Output Register B (0x25)
  sbi PORTB, PB5       ; Set PB5 high (LED on) (PORTB |= (1 << 5))
  rcall delay          ; Call delay subroutine (uses 16-bit Z register)
  cbi PORTB, PB5       ; Clear PB5 (LED off) (PORTB &= ~(1 << 5))
  rcall delay          ; Call delay again
  rjmp loop            ; Relative jump back to loop (infinite repetition)

;--- Software Delay Subroutine -----------------------------------------------------
delay:
  ; Delay calculation parameters:
  ; - CPU Clock: 16MHz = 16,000,000 cycles/sec
  ; - 1 cycle = 62.5ns
  ; - Nested loop structure for long delays
  ldi r20, 100         ; Outer loop counter (100 iterations)
outer_loop:
  ; Initialize 16-bit counter in Z register (R30/R31 pair)
  ldi r30, lo8(28000)  ; Low byte of inner loop count (28000 = 0x6D60)
  ldi r31, hi8(28000)  ; High byte of inner loop count
inner_loop:
  ; sbiw: Subtract Immediate from Word (Z register)
  ; - 2 cycles to execute
  ; - Affects Status Register (SREG) Zero flag
  sbiw r30, 1          ; Z = Z - 1 (16-bit decrement)
  brne inner_loop       ; Branch if Z != 0 (2 cycles if taken, 1 if not)

  ; Outer loop control
  dec r20              ; Decrement outer counter (1 cycle)
  brne outer_loop      ; Branch back if outer counter != 0 (2 cycles if taken)
  ret                  ; Return to caller (4 cycles)

;================================================================================
; ATmega328P Architecture Key Points:
; 1. I/O Memory Space:
;    - 64 I/O registers (0x00-0x3F) directly accessible via IN/OUT instructions
;    - Extended I/O (0x60-0xFF) accessible via LD/ST instructions
;
; 2. Clock System:
;    - 16MHz internal oscillator (1 cycle per instruction for most operations)
;    - Each instruction takes 1-4 cycles (brne=2 if taken, ret=4, etc.)
;
; 3. GPIO System:
;    - 3 Control Registers per Port (DDRx, PORTx, PINx)
;    - PB5 is physical pin 19 on DIP-28 package (Arduino Digital Pin 13)
;
; 4. Delay Calculation (Approximate):
;    Total cycles per delay call:
;    = (inner_loop_cycles * inner_count + outer_overhead) * outer_count
;    inner_loop_cycles = 3 cycles/sbiw-brne (except last iteration: 2 cycles)
;    outer_overhead = 3 cycles (ldi Z) + 4 cycles (dec-brne)
;    Actual delay ≈ (3*28000 - 1 + 3) * 100 ≈ 8,400,000 cycles ≈ 525ms
;    Total cycle time (on+off) ≈ 1.05s
;
; 5. Stack Operation:
;    - Grows downward from RAMEND (0x08FF)
;    - Critical for function calls (rcall pushes 2-byte return address)
;================================================================================
;
;             
;          <ARDUINO-PINS>          +-----\/-----+                   <ARDUINO-PINS>
;          RESET BUTTON   (RESET) -|1 PC6    PC5|- 28 --> ADC5/SCL  Analog Input 5
;          Digital Pin 0    (RXD) -|2 PD0    PC4|- 27 --> ADC4/SDA  Analog Input 4
;          Digital Pin 1    (TXD) -|3 PD1    PC3|- 26 --> ADC3      Analog Input 3
;          Digital Pin 2   (INT0) -|4 PD2    PC2|- 25 --> ADC2      Analog Input 2
;          Digital Pin 3   (INT1) -|5 PD3    PC1|- 24 --> ADC1      Analog Input 1
;          Digital Pin 4     (T0) -|6 PD4    PC0|- 23 --> ADC0      Analog Input 0
;          Voltage           VCC  -|7         22|- GND               Ground (GND)
;          Ground            GND  -|8         21|- PB7 (SCK)         Analog Reference
;          (Crystal)         XTAL -|9         20|- PB6 (MISO)        Voltage (VCC)
;          (Crystal)         XTAL -|10        19|- PB5 (MOSI/D13)   Digital Pin 13      <--- LED PIN (CODE USES THIS!)
;          Digital Pin 5   (OC1B) -|11 PD5    18|- PB4 (OC2/SS)     Digital Pin 12
;          Digital Pin 6   (OC1A) -|12 PD6    17|- PB3 (OC0)        Digital Pin 11 (PWM)
;          Digital Pin 7   (OC0B) -|13 PD7    16|- PB2 (ICP1)       Digital Pin 10 (PWM)
;          Digital Pin 8   (OC0A) -|14 PB0    15|- PB1 (T1)         Digital Pin  9 (PWM)
;                                  +------------+
;
;
;
;   Key Pin Correlation to Code
;  1.PB5 (Pin 19)
;      -Code:
;
;     ```assembly
;
;     sbi DDRB, PB5   ; Set PB5 (D13) as output
;     sbi PORTB, PB5  ; Turn LED on
;
;     ```
;
;
;    Hardware:
;     Connected to Arduino Uno's onboard LED (D13) via current-limiting resistor.
;
;  2.VCC (Pin 7) / GND (Pin 8/22)**
;   -Function: 5V power supply and ground (Arduino handles this).
;
;  3.XTAL1/XTAL2 (Pins 9-10)
;    -Clock Source:** 16MHz crystal (used for timing calculations in your delay loop)
;
;
;
;   ATmega328P Architecture Breakdown
;  1. Memory Map (Harvard Architecture)
;
;   +-----------------+ 0x0000
;   | Program Memory  | <-- Your code (.text section) lives here
;   | (32KB Flash)    |
;   +-----------------+ 0x7FFF
;
;   +-----------------+ 0x0000 (separate!)
;   | Data Memory      |
;   | - Registers     | <-- DDRB (0x24), PORTB (0x25) accessed via `sbi/cbi`
;   | - I/O Registers |
;   | - SRAM          | <-- Stack grows downward from 0x08FF (RAMEND)
;   +-----------------+ 0x08FF
;
;
;
;    2. GPIO Subsystem
;-   Port B (Pins 14-21):
;  - 8-bit bidirectional I/O port (`DDRB` = data direction, `PORTB` = output).
;  - Your code uses **Bit 5 (PB5)** to control the LED.;
;
;-   Critical Registers:
;  -  DDRB (0x24):
;    ```asm
;    sbi DDRB, PB5  ; Bit 5 = 1 → Output mode
;    ```
;  - PORTB (0x25):
;    ```asm
;    sbi PORTB, PB5 ; Bit 5 = 1 → 5V output (LED on)
;    cbi PORTB, PB5 ; Bit 5 = 0 → 0V output (LED off)
;    ```
;
;     3. Clock System
;- 16MHz external crystal** → 62.5ns clock cycle.
;- Delay Subroutine:
;  Your nested loops use the CPU’s cycle-counting for timing:
;  ```asm
;  sbiw r30, 1  ; 2 cycles
;  brne inner_loop ; 2 cycles (taken)
;  ```
;  Total delay ≈ (3 cycles/iter × 28,000 × 100) = 8,400,000 cycles ≈ 525ms.
;
;
;---
;
;   Physical ↔ Code Relationship
;
;
;   ATmega328P (Chip)        Arduino Uno Board          Your Code
;   +----------------+       +----------------+       +----------------+
;   | PB5 (Pin 19)   | <---->| D13 (LED)      | <---->| sbi PORTB, PB5 |
;   | XTAL1 (Pin 9)  | <---->| 16MHz Crystal  | <---->| Delay timing   |
;   | VCC (Pin 7)    | <---->| 5V Regulator   |       |                |
;   +----------------+       +----------------+       +----------------+
;
;   ┌────────────────────┬─────────────┬──────────────────────────────────┬───────────┐
;   │   Instruction      │ Operands    │ Description                      │ Cycles    │
;   ├────────────────────┼─────────────┼──────────────────────────────────┼───────────┤
;   │ LDI                │ Rd, K       │ Load Immediate (R16-R31 only)    │ 1         │
;   │ MOV                │ Rd, Rr      │ Copy Register                    │ 1         │
;   │ OUT                │ A, Rr       │ Write I/O Register               │ 1         │
;   │ IN                 │ Rd, A       │ Read I/O Register                │ 1         │
;   │ SBI/CBI            │ A, b        │ Set/Clear I/O Bit                │ 2         │
;   │ RJMP/RCALL         │ k           │ Relative Jump/Call (±2KB)        │ 2/3       │
;   │ BRNE/BREQ          │ k           │ Branch if Not Equal/Equal        │ 1/2       │
;   │ SBIW/ADIW          │ Rd, K       │ Subtract/Add Immediate to Word   │ 2         │
;   │ PUSH/POP           │ Rr          │ Stack Operations                 │ 2/2       │
;   │ RET                │             │ Return from Subroutine           │ 4         │
;   └────────────────────┴─────────────┴──────────────────────────────────┴───────────┘
;
;
;    
;
;
;
;
;