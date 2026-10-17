# Silverfox Instruction Set Architecture

> **Status:** Draft (v0.3)

**Instruction width:** 16 bits
**Program memory:** 64 x 16-bit instructions
**Program counter:** 6 bits
**Primary purpose:** deterministic protocol emulation and
timing-sensitive GPIO control

---

## 1. Overview

Silverfox is a small, deterministic PIO-inspired processor designed
specifically for implementing and emulating digital communication
protocols in software-controlled hardware.

The architecture is optimized for workloads such as:

- UART
- SPI
- I2C
- JTAG
- simple proprietary serial protocols
- timing-sensitive GPIO generation
- timing-sensitive GPIO capture
- protocol debugging and reverse engineering

Silverfox is not a general-purpose CPU. It behaves more like a
programmable protocol state machine than a conventional processor.

The ISA therefore prioritizes:

- deterministic cycle timing
- compact protocol loops
- direct GPIO manipulation
- exact delays
- pin-level waits
- edge detection
- serial shifting
- bidirectional I/O
- open-drain signaling
- simple hardware
- strong verification

The ISA deliberately avoids general-purpose CPU features:

- **A general-purpose ALU.** Protocols mostly need counting and shifting,
  which `JMP C_NZ_DEC`, `IN` and `OUT` already provide. A full ALU would
  cost area and multiply the cases to verify.
- **Load/store memory instructions.** Protocol state fits in X, Y, C and
  the GPIO registers. Data memory would add area and risk variable-latency
  accesses that break exact timing.
- **Interrupts.** An interrupt can divert execution on any cycle, which
  breaks the guarantee that a loop takes a fixed number of cycles. `WAIT`
  covers the useful part: stalling precisely until an input event.

The core vision is that nearly every instruction should directly
help implement a protocol.

## 2. Architectural state

| State | Width | Purpose |
|-------|-------|---------|
| `PC`    | 6 bits | Program counter over 64 × 16-bit instruction words |
| `X`, `Y` | 8 bits each | Data/shift registers, e.g. X = byte to send, Y = byte received |
| `C` | 8 bits | Loop counter, so counting doesn't use up X or Y |
| `PINS_OUT` | 8 bits | Output values for the 8 bidirectional `uio` pins |
| `PINS_OE` | 8 bits | Output enables for `uio`: 1 = drive, 0 = high-impedance |
| `UO_OUT` | 8 bits | Values for the 8 output-only `uo` pins |

The table lists the state programs can read or write. The machine also
keeps internal state that programs cannot access directly: a **halted**
flag, the **DELAY counter**, and **WAIT's previous input sample** (needed
to detect edges).

Programs read inputs from the `ui_in` (input-only) and `uio_in`
(bidirectional) pin banks. Pins reserved for the host interface are masked
off by the top-level wrapper, so programs never see or drive them.

### Reset state

On reset (`rst_n` low):

| State | Reset value |
|---|---|
| `PC` | 0 |
| `X`, `Y`, `C` | 0 |
| `PINS_OUT` | 0 |
| `PINS_OE` | 0, so all `uio` pins start high-impedance |
| `UO_OUT` | 0 |
| Program memory | `0xE000` (HALT) in every word |

Filling program memory with HALT means an empty or partly loaded program
stops cleanly instead of running into undefined instructions.

The baseline instruction set contains only eight major
instruction classes:

```text
SET
WAIT
IN
OUT
JMP
MOV
DELAY
SYS
```

Each exists because it directly supports protocol execution.

For example:

- `SET` changes registers or GPIO state.
- `WAIT` synchronizes execution to input levels or edges.
- `IN` shifts sampled bits into a register.
- `OUT` shifts bits onto an output pin.
- `JMP` implements control flow and counted loops.
- `MOV` moves parallel data between architectural resources.
- `DELAY` produces exact timing intervals.
- `SYS` contains system-level operations such as `NOP` and `HALT`.

## 3. Instruction format

Every instruction is 16 bits:

```text
 15    13 12    10 9                0
+--------+--------+-----------------+
| opcode |  arg1  |      arg2       |
+--------+--------+-----------------+
  3 bits   3 bits      10 bits
```

The meaning of `arg1` and `arg2` depends on the opcode.

`DELAY` is the one exception: it uses all 13 operand bits as a single number.

Bits an instruction does not use are reserved and must be zero. A word
with a nonzero reserved bit is illegal (see section 6).

## 4. Opcode map

| Opcode | Name | Cycles | Purpose |
|---|---|---|---|
| `000`  | SET  | 1      | Load a register, or write/set/clear/toggle GPIO bits |
| `001`  | WAIT | 1 or more (until the condition holds) | Stall until a pin is low/high or sees a rising/falling edge |
| `010` | IN | 1 | Sample one pin, shift the bit into X or Y |
| `011` | OUT | 1 | Shift one bit from X or Y onto a pin |
| `100` | JMP | 1 | Branch: always, on zero, counted loop, or on a pin |
| `101` | MOV | 1 | Copy 8 bits from a register or input bank into a register or GPIO register |
| `110` | DELAY | exactly N | Stall for exactly N cycles (1-8192) |
| `111` | SYS | 1 (HALT: forever) | HALT, NOP, and room for future system ops |

Extensibility is provided through sub-operation fields within
instructions such as `SYS`.

## 5. Instructions

<!-- Template for each instruction:
     Purpose        - one or two sentences
     Syntax         - assembly form
     Encoding       - bit layout diagram
     Field codes    - a table per field
     Semantics      - what it does to the architectural state
     Rules          - illegal forms and restrictions
     Example        - one worked encoding (operand bits and full word)
-->

### 5.1 SET

**Purpose:**
`SET` writes or modifies architectural state.

It can be used to:

- load X
- load Y
- load C
- write GPIO values
- set GPIO bits
- clear GPIO bits
- toggle GPIO bits
- configure output-enable state

**Syntax:**

```asm
SET    reg, value        ; reg = X | Y | C
SET    gpio, mask        ; gpio = PINS_OUT | PINS_OE | UO_OUT  (set bits)
CLEAR  gpio, mask
TOGGLE gpio, mask
WRITE  gpio, value
```

**Encoding:**

```text
15        13 12        10 9   8 7                 0
+------------+------------+-----+-------------------+
|    000     | destination| op  |       value       |
+------------+------------+-----+-------------------+
   opcode        arg1       2b          8b
```

**Field codes:**

Destination (`arg1`, bits 12..10):

| Code | Destination | Kind |
|---|---|---|
| `000` | X | register |
| `001` | Y | register |
| `010` | C | register |
| `011` | PINS_OUT | GPIO register |
| `100` | PINS_OE | GPIO register |
| `101` | UO_OUT | GPIO register |
| `110` | — | reserved |
| `111` | — | reserved |

Operation (bits 9..8):

| Code | Operation |
|---|---|
| `00` | WRITE |
| `01` | SET_BITS |
| `10` | CLEAR_BITS |
| `11` | TOGGLE_BITS |

Value (bits 7..0): an 8-bit immediate. For WRITE it is the new value; for
the bit operations it is a mask, where each 1 selects one bit (one pin).

**Semantics:**

```text
WRITE       dest, v   dest <- v
SET_BITS    gpio, m   gpio <- gpio OR m
CLEAR_BITS  gpio, m   gpio <- gpio AND (NOT m)
TOGGLE_BITS gpio, m   gpio <- gpio XOR m

all forms             PC <- PC + 1
```

Only the selected destination changes. Bits of a GPIO register whose mask
bit is 0 keep their value. `SET` takes 1 cycle.

**Rules:**

- X, Y and C support WRITE only. A SET with a register destination and any
  other operation code is illegal.
- Destination codes `110` and `111` are reserved; words using them are
  illegal.
- SET uses all 13 operand bits, so it has no reserved bits.

**Example:**

Set bit 0 of PINS_OUT (drive `uio` pin 0's output value high, leaving the
other pins unchanged):

```text
SET PINS_OUT, 0x01   (SET_BITS)

opcode       000      (SET)
destination  011      (PINS_OUT)
operation    01       (SET_BITS)
value        00000001 (mask: bit 0)

bit:   15 14 13 | 12 11 10 |  9  8 |  7  6  5  4  3  2  1  0
        0  0  0 |  0  1  1 |  0  1 |  0  0  0  0  0  0  0  1

word:  0x0D01
```


### 5.2 WAIT

**Purpose:**
`WAIT` stalls program execution until an input condition becomes true. It
synchronizes a program to external events, such as the falling edge of a
UART start bit, without busy-looping.

Supported conditions: `LOW` and `HIGH` (levels) and `RISE` and `FALL`
(true edges).

**Syntax:**

```asm
WAIT condition, bank.pin     ; condition = low | high | rise | fall
                             ; bank = ui | uio, pin = 0..7
```

Examples:

```asm
WAIT fall, ui.0      ; wait for a falling edge on ui_in[0]  (UART start bit)
WAIT high, uio.1     ; wait until uio[1] is high            (I2C clock stretching)
```

**Encoding:**

```text
15     13 12     10 9                3  2    1  0
+--------+--------+-------------------+----+------+
|  001   |  pin   |   reserved (0)    |bank| cond |
+--------+--------+-------------------+----+------+
 opcode    arg1                         1b    2b
```

**Field codes:**

Pin (`arg1`, bits 12..10): pin number 0..7.

Bank (bit 2):

| Code | Bank |
|---|---|
| `0` | UIO (`uio_in`) |
| `1` | UI (`ui_in`) |

Condition (bits 1..0):

| Code | Condition | Completes when |
|---|---|---|
| `00` | LOW | the pin is 0 |
| `01` | HIGH | the pin is 1 |
| `10` | RISE | the previous sample was 0 and the current sample is 1 |
| `11` | FALL | the previous sample was 1 and the current sample is 0 |

**Semantics:**

```text
if condition holds:  PC <- PC + 1
else:                PC <- PC     (stall; try again next cycle)
```

No other architectural state changes. Edge conditions compare the current
input sample with the previous one, which the machine keeps internally
(see section 2). A WAIT whose condition already holds completes in one
cycle.

**Rules:**

- Bits 9..3 are reserved and must be zero.
- How the input synchronizer's latency and the previous-sample register
  behave exactly is still open (see section 9).

**Example:**

```text
WAIT fall, ui.0

opcode     001
pin        000   (0)
bank       1     (UI)
condition  11    (FALL)

bit:   15 14 13 | 12 11 10 |  9 ..  3 |  2 |  1  0
        0  0  1 |  0  0  0 |  0 ..  0 |  1 |  1  1

word:  0x2007
```

### 5.3 IN

**Purpose:**
`IN` samples one input pin and shifts the bit into X or Y. It is the
building block of serial reception: eight `IN`s assemble a received byte.

**Syntax:**

```asm
IN reg, bank.pin, order      ; reg = X | Y, bank = ui | uio, order = lsb | msb
```

Example:

```asm
IN X, ui.0, lsb      ; shift the UART RX bit into X, LSB-first
```

**Encoding:**

```text
15     13 12     10 9                3  2     1     0
+--------+--------+-------------------+----+-----+-----+
|  010   |  pin   |   reserved (0)    |bank|order| reg |
+--------+--------+-------------------+----+-----+-----+
 opcode    arg1                         1b    1b    1b
```

**Field codes:**

| Field | Bits | `0` | `1` |
|---|---|---|---|
| reg | 0 | X | Y |
| order | 1 | LSB-first | MSB-first |
| bank | 2 | UIO | UI |

Pin (`arg1`, bits 12..10): pin number 0..7.

**Semantics:**

```text
b <- the sampled input bit

LSB-first:  reg <- { b, reg[7:1] }    (shift right, new bit enters at bit 7)
MSB-first:  reg <- { reg[6:0], b }    (shift left,  new bit enters at bit 0)

PC <- PC + 1
```

After eight LSB-first `IN`s, the first bit received ends up in bit 0, which
matches UART (LSB-first) order. After eight MSB-first `IN`s, the first bit
received ends up in bit 7, which matches SPI's usual MSB-first order. `IN`
takes 1 cycle.

**Rules:**

- Bits 9..3 are reserved and must be zero.

**Example:**

```text
IN Y, ui.5, msb

opcode  010
pin     101   (5)
bank    1     (UI)
order   1     (MSB-first)
reg     1     (Y)

bit:   15 14 13 | 12 11 10 |  9 ..  3 |  2 |  1 |  0
        0  1  0 |  1  0  1 |  0 ..  0 |  1 |  1 |  1

word:  0x5407
```

### 5.4 OUT

**Purpose:**
`OUT` shifts one bit out of X or Y onto an output pin. It is the building
block of serial transmission. An open-drain mode supports wired-AND buses
such as I2C.

**Syntax:**

```asm
OUT bank.pin, reg, order          ; push-pull
OUT uio.pin, reg, order, od       ; open-drain (UIO only)
                                  ; bank = uio | uo, reg = X | Y, order = lsb | msb
```

Examples:

```asm
OUT uo.0, X, lsb        ; UART TX bit on uo_out[0]
OUT uio.0, X, msb, od   ; I2C SDA bit, open-drain
```

**Encoding:**

```text
15     13 12     10 9             4  3    2     1     0
+--------+--------+----------------+----+----+-----+-----+
|  011   |  pin   |  reserved (0)  |mode|bank|order| reg |
+--------+--------+----------------+----+----+-----+-----+
 opcode    arg1                      1b   1b    1b    1b
```

**Field codes:**

| Field | Bits | `0` | `1` |
|---|---|---|---|
| reg | 0 | X | Y |
| order | 1 | LSB-first | MSB-first |
| bank | 2 | UIO | UO |
| mode | 3 | push-pull | open-drain |

Pin (`arg1`, bits 12..10): pin number 0..7.

**Semantics:**

```text
LSB-first:  b <- reg[0];  reg <- { 0, reg[7:1] }
MSB-first:  b <- reg[7];  reg <- { reg[6:0], 0 }

UO, push-pull:    UO_OUT[pin]   <- b
UIO, push-pull:   PINS_OUT[pin] <- b          (PINS_OE unchanged)
UIO, open-drain:  if b = 0:  PINS_OUT[pin] <- 0;  PINS_OE[pin] <- 1   (drive low)
                  if b = 1:  PINS_OE[pin]  <- 0                       (release)

PC <- PC + 1
```

Push-pull `OUT` on UIO does not change the pin's direction; set `PINS_OE`
first with `SET`. In open-drain mode the core never actively drives a logic
1: a 1 releases the pin and an external pull-up pulls it high. `OUT` takes
1 cycle.

**Rules:**

- Open-drain on UO (bank = 1 and mode = 1) is illegal, because the `uo`
  pins have no output enable.
- Bits 9..4 are reserved and must be zero.

**Example:**

```text
OUT uio.4, Y, msb, od

opcode  011
pin     100   (4)
mode    1     (open-drain)
bank    0     (UIO)
order   1     (MSB-first)
reg     1     (Y)

bit:   15 14 13 | 12 11 10 |  9 ..  4 |  3 |  2 |  1 |  0
        0  1  1 |  1  0  0 |  0 ..  0 |  1 |  0 |  1 |  1

word:  0x700B
```

### 5.5 JMP

**Purpose:**
`JMP` is the only control-flow instruction. It covers unconditional jumps,
tests for zero, counted loops, and branching on an input pin (e.g. a UART
stop-bit check or an I2C ACK/NACK).

**Syntax:**

```asm
JMP target                     ; always
JMP X_ZERO, target             ; also Y_ZERO, C_ZERO
JMP C_NZ_DEC, target           ; counted loop
JMP LOW, bank.pin, target      ; also HIGH; bank = ui | uio
```

`target` is an absolute address 0..63, normally written as a label.

**Encoding:**

Non-pin conditions:

```text
15     13 12     10 9          6 5             0
+--------+--------+-------------+---------------+
|  100   |  cond  | reserved (0)|    target     |
+--------+--------+-------------+---------------+
```

Pin conditions (`LOW`, `HIGH`):

```text
15     13 12     10   9    8    6 5             0
+--------+--------+------+------+---------------+
|  100   |  cond  | bank | pin  |    target     |
+--------+--------+------+------+---------------+
```

**Field codes:**

Condition (`arg1`, bits 12..10):

| Code | Condition | Jumps when |
|---|---|---|
| `000` | ALWAYS | always |
| `001` | X_ZERO | X = 0 |
| `010` | Y_ZERO | Y = 0 |
| `011` | C_ZERO | C = 0 |
| `100` | C_NZ_DEC | counted loop, see Semantics |
| `101` | LOW | the selected pin is 0 |
| `110` | HIGH | the selected pin is 1 |
| `111` | — | reserved |

Target (bits 5..0): absolute address 0..63.

For pin conditions only: bank (bit 9, `0` = UIO, `1` = UI) and pin
(bits 8..6, 0..7).

**Semantics:**

```text
ALWAYS, X_ZERO, Y_ZERO, C_ZERO, LOW, HIGH:
  if condition:  PC <- target
  else:          PC <- PC + 1

C_NZ_DEC:
  if C = 0:      PC <- PC + 1                      (C unchanged, no underflow)
  else:          C <- C - 1
                 if C (new value) != 0:  PC <- target
                 else:                   PC <- PC + 1
```

The zero tests do not modify the register they test. With the counted loop

```asm
    SET C, n
loop:
    ...                    ; loop body
    JMP C_NZ_DEC, loop
```

the body runs exactly n times for n = 1..255. Because the test is at the
end, the body always runs at least once; with n = 0 it runs once. `JMP`
takes 1 cycle, whether or not the jump is taken.

**Rules:**

- Condition code `111` is reserved.
- For non-pin conditions, bits 9..6 are reserved and must be zero.

**Example:**

```text
JMP HIGH, ui.3, 10

opcode     100
condition  110      (HIGH)
bank       1        (UI)
pin        011      (3)
target     001010   (10)

bit:   15 14 13 | 12 11 10 |  9 |  8  7  6 |  5  4  3  2  1  0
        1  0  0 |  1  1  0 |  1 |  0  1  1 |  0  0  1  0  1  0

word:  0x9ACA
```

### 5.6 MOV

**Purpose:**
`MOV` copies a whole 8-bit value from one place to another, for example a
parallel read of all input pins into X, or a whole byte from X onto the
output pins.

**Syntax:**

```asm
MOV destination, source
```

Examples:

```asm
MOV X, UI_IN         ; read all eight ui_in pins into X
MOV PINS_OUT, X      ; drive X onto the uio output values
```

**Encoding:**

```text
15     13 12     10 9                3 2      0
+--------+--------+-------------------+--------+
|  101   |  dest  |   reserved (0)    | source |
+--------+--------+-------------------+--------+
 opcode    arg1                           3b
```

**Field codes:**

Both fields use the same numbering. The input banks are read-only, so they
are only valid as sources:

| Code | Source | Destination |
|---|---|---|
| `000` | X | X |
| `001` | Y | Y |
| `010` | C | C |
| `011` | UI_IN | — illegal |
| `100` | UIO_IN | — illegal |
| `101` | PINS_OUT | PINS_OUT |
| `110` | PINS_OE | PINS_OE |
| `111` | UO_OUT | UO_OUT |

**Semantics:**

```text
destination <- source
PC <- PC + 1
```

The source is not modified. Reading `PINS_OUT`, `PINS_OE` or `UO_OUT`
returns the register's value, not the level on the pin. Reading `UI_IN`
or `UIO_IN` returns the input pins, with host-reserved pins masked off
(see section 2). `MOV` takes 1 cycle.

**Rules:**

- Destination codes `011` (UI_IN) and `100` (UIO_IN) are illegal.
- Bits 9..3 are reserved and must be zero.

**Example:**

```text
MOV X, UI_IN

opcode       101
destination  000   (X)
source       011   (UI_IN)

bit:   15 14 13 | 12 11 10 |  9 ..  3 |  2  1  0
        1  0  1 |  0  0  0 |  0 ..  0 |  0  1  1

word:  0xA003
```

### 5.7 DELAY

**Purpose:**
`DELAY` stalls execution for an exact number of clock cycles. It replaces
the countdown loops the earlier ISA needed for protocol timing, which cost
instruction memory and were easy to get wrong.

**Syntax:**

```asm
DELAY n          ; n = 1..8192 cycles
```

**Encoding:**

```text
15     13 12                                     0
+--------+----------------------------------------+
|  110   |              cycles - 1                |
+--------+----------------------------------------+
 opcode                   13 bits
```

**Field codes:**

Bits 12..0 hold the number of cycles minus one:

| Field value | Cycles |
|---|---|
| `0` | 1 |
| `1` | 2 |
| ... | ... |
| `8191` | 8192 |

There is no zero-cycle delay.

**Semantics:**

```text
occupy exactly n cycles, then:
PC <- PC + 1
```

While a DELAY runs, the PC stays on the DELAY instruction and no
architectural state changes; GPIO outputs hold their values. Delays longer
than 8192 cycles use several DELAYs in a row.

**Rules:**

- Every 13-bit value is legal; DELAY has no reserved bits.
- When computing protocol timing, subtract the cost of the other
  instructions in a loop from the DELAY (see section 7).

**Example:**

```text
DELAY 102

opcode  110
field   0000001100101   (101 = 102 - 1)

bit:   15 14 13 | 12 ................. 0
        1  1  0 |  0 0000 0110 0101

word:  0xC065
```

### 5.8 SYS

**Purpose:**
`SYS` holds system-level operations: `HALT` and `NOP`. Its unused sub-op
codes leave room for future system operations without using up a major
opcode.

**Syntax:**

```asm
HALT
NOP
```

**Encoding:**

```text
15     13 12     10 9                        0
+--------+--------+---------------------------+
|  111   | sub-op |       reserved (0)        |
+--------+--------+---------------------------+
 opcode    arg1
```

**Field codes:**

| Code | Operation |
|---|---|
| `000` | HALT |
| `001` | NOP |
| `010`-`111` | reserved |

**Semantics:**

```text
HALT:  PC <- PC; execution stops
NOP:   PC <- PC + 1
```

After HALT, the core stays halted until reset or until the host restarts
it. `NOP` takes 1 cycle.

HALT is deliberately sub-op `000`, so the full word is `0xE000`. Program
memory resets to `0xE000` in every word (see section 2), so an empty or
partly loaded program halts.

**Rules:**

- Sub-op codes `010` to `111` are reserved.
- Bits 9..0 are reserved and must be zero.

**Example:**

```text
HALT

opcode  111
sub-op  000   (HALT)

bit:   15 14 13 | 12 11 10 |  9 ..  0
        1  1  1 |  0  0  0 |  0 ..  0

word:  0xE000
```

## 6. Illegal and reserved encodings

Every one of the 65,536 possible 16-bit words is either a legal
instruction or illegal. A word is illegal if it uses a reserved code or a
forbidden combination, or has a nonzero reserved bit:

| Instruction | Reserved codes and forbidden combinations | Reserved bits |
|---|---|---|
| SET | destinations `110`, `111`; any operation other than WRITE on X, Y or C | none |
| WAIT | none | 9..3 |
| IN | none | 9..3 |
| OUT | open-drain on UO (bank = 1, mode = 1) | 9..4 |
| JMP | condition `111` | 9..6 for non-pin conditions |
| MOV | destinations `011` (UI_IN), `100` (UIO_IN) | 9..3 |
| DELAY | none | none |
| SYS | sub-ops `010` to `111` | 9..0 |

This classification is verified exhaustively in
`hardcaml/test/isa_test.ml`: every word either fails to decode or decodes to
an instruction that re-encodes to exactly that word. There are 14,674 legal
words, the same as the number of legal instructions, so the encoding is
one-to-one.

What the hardware does when it fetches an illegal word is not decided yet
(see section 9).

## 7. Timing

Every instruction takes a fixed number of cycles, except `WAIT`:

| Instruction | Cycles |
|---|---|
| SET, IN, OUT, JMP, MOV | 1 |
| DELAY n | n (1..8192) |
| WAIT | 1 or more, until the condition holds |
| SYS NOP | 1 |
| SYS HALT | never completes |

The same table is implemented as `Instruction.cycles` in
`hardcaml/lib/isa/isa.ml`.

The time a loop takes is the sum of the costs of the instructions in it,
so a DELAY inside a loop must account for the other instructions. For
example, to send one UART bit every P cycles:

```asm
loop:
    OUT  uo.0, X, lsb        ; 1 cycle
    DELAY P-2                ; P-2 cycles
    JMP  C_NZ_DEC, loop      ; 1 cycle      -> P cycles per bit
```

Writing `DELAY P` here would make every bit 2 cycles too long.

## 8. Example programs

To be added once the reference model can run them, so that every example
in this document has been executed and checked.

## 9. Open questions

Not decided yet; to be resolved before declaring the ISA stable:

- Input synchronizer latency, and how it shows up in WAIT, IN and pin JMP.
- Whether WAIT's previous-sample register updates during DELAY (an edge
  during a DELAY could otherwise be missed or caught).
- On which cycle a registered output becomes visible on the pin.
- What the hardware does when it fetches an illegal instruction word.
- What happens when the PC passes address 63 (wrap to 0, or halt).
- The minimum WAIT cost when the condition already holds (assumed 1 cycle).
- The host data path: how the host passes bytes into and out of the core.
- Assembly syntax details, such as the names of the SET operations.

## 10. Version history

- **v0.1** — Eight 32-bit general-purpose registers, Z/C flags, a general
  ALU, timing registers and 256 instruction words. Dropped as too CPU-like:
  large in area and costly to verify.
- **v0.2** — Narrowed to X, Y and a dedicated loop counter C (8 bits each),
  eight instruction classes including DELAY, and 64 instruction words.
- **v0.3** — HALT moved to SYS `000`, so reset-filled memory (`0xE000`)
  halts; OUT gained a UIO/UO bank bit; JMP gained pin conditions;
  `C_NZ_DEC` no longer underflows at 0; illegal forms made explicit.
  Implemented in `hardcaml/lib/isa/isa.ml` with exhaustive tests.

See `docs/decisions.md` for the reasoning behind each change.
