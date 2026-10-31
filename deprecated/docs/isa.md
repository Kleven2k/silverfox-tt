# ISA Reference

> **Status:** Living document - this reflects the ISA as currently
> implemented. All seven opcodes are implemented and tested (SET, WAIT,
> IN, OUT, JMP, MOV, HALT); MOV has no dedicated unit test (treated as
> low-risk given its simplicity). See `decisions.md` for the reasoning
> behind changes, and `roadmap.md` for what's next.

SilverFox's core is a small, PIO-inspired CPU: an instruction set designed
around reading pins, writing pins, counting cycles, and branching on pin
state - enough to bit-bang a real protocol in firmware instead of fixed
logic. Design inspired by the RP2040's PIO state machines.

## Instruction format

Instructions are 16 bit wide:

| Bits    | 15–13    | 12–10   | 9–0     |
|---------|----------|---------|---------|
| Field   | opcode   | arg1    | arg2    |

- **opcode** (`instr[15:13]`, 3 bits) - selects the operation
- **arg1** (`instr[12:10]`, 3 bits) - meaning depends on opcode: a
  condition code for `JMP`, a pin/register selector for `SET`/`OUT`/`IN`/`MOV`
- **arg2** (`instr[9:0]`, 10 bits) - meaning depends on opcode:
    - For `JMP`, the low 5 bits (`arg2[4:0]`) are the jump target address
    - For `SET`/`MOV`, the low 8 bits (`arg2[7:0]`) are an 8-bit immediate value

Program memory currently holds 32 instructions (5-bit program counter).
This is a starting size, not a hard architectural limit - see
`decisions.md` for the reasoning and revisit criteria. The current UART
RX program uses all 30 instructions exactly, with no spare room.

## Opcodes

| Opcode | Bits  | Status      | Description                                  |
|--------|-------|-------------|-----------------------------------------------|
| `SET`  | `000` | Implemented | Set a pin or register to an immediate value  |
| `WAIT` | `001` | Implemented | Stall until a pin condition is met           |
| `IN`   | `010` | Implemented | Shift a pin's value into a register          |
| `OUT`  | `011` | Implemented | Shift a register's value out to a pin        |
| `JMP`  | `100` | Implemented | Conditional or unconditional jump            |
| `MOV`  | `101` | Implemented | Parallel-load a register from an input group |
| -      | `110` | Reserved    | Unused                                       |
| `HALT` | `111` | Implemented | Stop execution (PC holds)                    |

### SET

Sets a pin or register to the value in `arg2[7:0]`. Which pin/register is
selected by `arg1` - see [Pin/register map](#pinregister-map) below.

Currently supports:
- `PIN_TX` - writes bit 0 of the immediate to the TX register
- `REG_X` - loads the full 8 bit immediate into the X register
- `REG_Y` - loads the full 8 bit immediate into the Y register

### WAIT

Holds the program counter in place (does not advance) until the RX pin's
value matches the target polarity in `arg2[0]`, then falls through to the
next instruction. Unlike `JMP`, `WAIT` never jumps to a different
address - it only blocks in place. This is the ISA's primary mechanism
for detecting an edge (e.g. a UART start bit dropping the line low):
since `WAIT` polls every cycle, it naturally falls through on the exact
cycle the condition first becomes true.

### IN

Shifts the current RX pin value into the X register from the MSB side:
`X <- {rx_bit, X[7:1]}`. Across 8 consecutive `IN` calls (typically
separated by a bit-period delay), this reconstructs a byte received
LSB-first: the earliest-received bit ends up at X's bit 0, the
last-received bit at X's bit 7.

### OUT

Sends X's current LSB out on the TX pin, then shifts X right by one:
`X <- {1'b0, X[7:1]}`. Across 8 consecutive `OUT` calls, this transmits
X's original value LSB-first.

### MOV

Parallel-loads all 8 bits of `ui_in` into the X register in a single
cycle, `X <- ui_in`. This is the only variant currently implemented;
`arg1` is reserved for future direction/source options (e.g. writing to
an output pin group) once needed.

### JMP

Jumps to the address in `arg2[4:0]` if the condition selected by `arg1` is
true; otherwise falls through to the next instruction. See
[Condition codes](#condition-codes) below.

When the condition is `COND_X_NOT_ZERO` or `COND_Y_NOT_ZERO` **and** the
jump is taken, the matching register (X or Y respectively) is decremented
as part of the same instruction - this mirrors the RP2040 PIO's combined
"decrement and branch" behavior, so a single instruction can drive a
delay loop.

### HALT

Execution stops; the program counter holds its current value indefinitely
(until reset). Used to pad unused program memory and as an explicit stop
instruction.

## Condition codes

Used as `arg1` when `opcode == JMP`.

| Code          | Bits  | Meaning                                 |
|---------------|-------|-----------------------------------------|
| `ALWAYS`      | `000` | Unconditional jump                      |
| `NOT_TXVALID` | `001` | Jump if `!tx_valid`                     |
| `X_NOT_ZERO`  | `010` | Jump if `X != 0` (and decrement X)      |
| `RX_HIGH`     | `011` | Jump if the RX pin currently reads high |
| `Y_NOT_ZERO`  | `100` | Jump if `Y != 0` (and decrement Y)      |

## Pin/register map

Used as `arg1` when `opcode == SET`.

| ID             | Bits  | Meaning                         |
|----------------|-------|----------------------------------|
| `PIN_TX`       | `000` | TX output pin                   |
| `PIN_TX_READY` | `001` | TX-ready status (not yet wired) |
| `REG_X`        | `010` | X register                      |
| `PIN_RX`       | `011` | RX input pin                    |
| `REG_Y`        | `100` | Y register                      |

## Registers

| Register | Width  | Purpose                                                                                 |
|----------|--------|-------------------------------------------------------------------------------------------|
| `PC`     | 5 bits | Program counter, indexes the 32-entry instruction memory                                  |
| `X`      | 8 bits | Scratch register: accumulates/shifts data via `IN`/`OUT`, or a delay-loop counter via `SET`/`JMP X_NOT_ZERO` |
| `Y`      | 8 bits | Second scratch register, dedicated to delay-loop counting via `SET`/`JMP Y_NOT_ZERO`, so a delay loop doesn't overwrite data `X` is simultaneously accumulating (needed by UART RX; see `decisions.md`) |
| `TX`     | 1 bit  | Current TX pin output value                                                                |

## Timing notes

**One-cycle register latency.** There is a one-cycle latency between an
instruction executing and its effect becoming visible on an output pin -
standard synchronous register behavior. See `decisions.md` for how this
was confirmed.

**Delay-loop cycle accounting.** A busy-wait delay loop of the form
`SET reg = n; JMP reg_not_zero -> self` takes exactly `n + 2` cycles
total: 1 cycle for the `SET`, then `n + 1` cycles for the `JMP` to hold
while it counts `reg` down to 0. Any instruction immediately preceding
this pair (e.g. `SET TX` before a TX bit's delay, or `IN` before an RX
bit's delay) adds its own cycle on top. Getting this overhead wrong is
easy and was a real bug in early UART TX/RX programs, silently running
protocols about 2 cycles slower per bit than their target baud rate - see
`decisions.md` for the full story and the `delay_loop_n` helper that now
computes this correctly in `hardcaml/src/programs/uart.ml`.

## Pin mapping (TT interface)

The core currently maps its I/O onto Tiny Tapeout's required pins as
follows (subject to change as more protocols are added):

| TT pin      | Width | Current use                           |
|-------------|-------|----------------------------------------|
| `ui_in[0]`  | 1 bit | RX, read via `IN`/`WAIT COND_RX_HIGH` |
| `uo_out[0]` | 1 bit | TX                                    |
| `uio_*`     | 8 bit | Unused so far (tied to zero)          |

This will need to expand once protocols requiring more pins (SPI, I2C)
are implemented, since each needs its own pin allocation.