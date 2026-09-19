# ISA Reference

> **Status:** Living document - this reflects the ISA as currently
> implemented and is expected to change as WAIT/IN/OUT/MOV are added and
> real protocols (UART, SPI, I2C) reveal gaps or missing primitives.
> Each opcode below is marked Implemented, Planned, or Reserved to make
> the current state clear at a glance. See `decisions.md` for the
> reasoning behind changes, and `roadmap.md` for what's next.

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
`decisions.md` for the reasoning and revisit criteria.

## Opcodes

| Opcode | Bits  | Status      | Description                                  |
|--------|-------|-------------|----------------------------------------------|
| `SET`  | `000` | Implemented | Set a pin or register to an immediate value |
| `WAIT` | `001` | Planned     | Stall until a pin condition is met           |
| `IN`   | `010` | Planned     | Read a pin's value into a register           |
| `OUT`  | `011` | Planned     | Write a register's value to a pin group      |
| `JMP`  | `100` | Implemented | Conditional or unconditional jump            |
| `MOV`  | `101` | Planned     | Move a value between registers/pins          |
| -      | `110` | Reserved    | Unused                                       |
| `HALT` | `111` | Implemented | Stop execution (PC holds)                    |

### SET

Sets a pin or register to the value in `arg2[7:0]`. Which pin/register is
selected by `arg1` - see [Pin/register map](#pinregister-map) below.

Currently supports:
- `PIN_TX` - writes bit 0 of the immediate to the TX register
- `REG_X` - loads the full 8 bit immediate into the X register

### JMP

Jumps to the address in `arg2[4:0]` if the condition selected by `arg1` is
true; otherwise falls through to the next instruction. See
[Condition codes](#condition-codes) below.

When the condition is `COND_X_NOT_ZERO` **and** the jump is taken, the X register is decremented as part of the same instruction - this mirrors the RP2040 PIO's combined "decrement and branch" behavior, so a single instruction can drive a delay loop.

### HALT

Execution stops; the program counter holds its current value indefinitely
(until reset). Used to pad unused program memory and as an explicit stop
instruction.

### WAIT, IN, OUT, MOV - planned

Not yet implemented. Expected roles, based on the original design:
- **WAIT** - stall the PC until a pin condition holds (the actual timing
    primitive protocols will be built from)
- **IN** - read a pin's current value into a register (needed for RX-side
    protocol logic)
- **OUT** -write a register's value out to a pin group (needed for
    multi-bit output, e.g. SPI/I2C data lines)
- **MOV** - move a value between registers or pins without going through
    an immediate

These will be added and documented here once implemented.

## Condition codes

Used as `arg1` when `opcode == JMP`.

| Code          | Bits  | Meaning                                 |
|---------------|-------|-----------------------------------------|
| `ALWAYS`      | `000` | Unconditional jump                      |
| `NOT_TXVALID` | `001` | Jump if `!tx_valid`                     |
| `X_NOT_ZERO`  | `010` | Jump if `X !=0` (and decrement X)       |
| `RX_HIGH`     | `011` | Jump if the RX pin currently reads high |

## Pin/register map

Used as `arg1` when `opcode == SET` or `OUT` (planned).

| ID             | Bits  | Meaning                         |
|----------------|-------|---------------------------------|
| `PIN_TX`       | `000` | TX output pin                   |
| `PIN_TX_READY` | `001` | TX-ready status (planned)       |
| `REG_X`        | `010` | X register (8-bit down-counter) |
| `PIN_RX`       | `011` | RX input pin (planned)          |

## Registers

| Register | Width  | Purpose                                                                 |
|----------|--------|-------------------------------------------------------------------------|
| `PC`     | 5 bits | Program counter, indexes the 32-entry instruction memory                |
| `X`      | 8 bits | General-purpose down-counter, used for delay loops via `JMP X_NOT_ZERO` |
| `TX`     | 1 bit  | Current TX pin output value                                             |

## Timing note: one-cycle register latency

There is a one-cycle latency between an instruction executing and its 
effect becoming visible on an output pin - standard synchronous register 
behavior, but worth calling out explicitly since it directly affects
bit-timing calculations for any protocol built on this core (e.g. UART
baud-rate cycle counts need to account for this offset). See
`decisions.md` for how this was confirmed.

## Pin mapping (TT interface)

The core currently maps its I/O onto Tiny Tapeout's required pins as
follows (subject to change as WAIT/IN/OUT/MOV and real protocols are
added):

| TT pin  | Width | Current use                    |
|---------|-------|--------------------------------|
| `ui_in[0]` | 1 bit | RX (planned; read via `COND_RX_HIGH`) |
| `uo_out[0]` | 1 bit | TX |
| `uio_*` | 8 bit | Unused so far (tied to zero) |

This will need to expand once real protocols (UART, SPI, I2C) are
implemented, since each needs its own pin allocation.
