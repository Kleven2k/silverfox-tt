# Silverfox Host Interface

**Version:** 0.3  
**Status:** Draft / living specification  
**Host transport:** 4-wire SPI slave  
**SPI mode:** Mode 0 (`CPOL=0`, `CPHA=0`)  
**System clock:** 25 MHz target, subject to post-STA adjustment  
**Maximum SCLK:** f_clk / 16 (provisionally 1 MHz at 25 MHz)  
**Program memory:** 64 × 16-bit instructions

---

## 1. Overview

The Silverfox host interface provides a control and debug path between an external host and the Silverfox protocol-emulator core.

The host interface is intentionally separate from the Silverfox ISA. Protocol programs execute using the architectural state and instructions defined by `isa.md`; the host interface is used to:

- stop execution safely;
- restart the CPU;
- write program memory;
- read program memory back;
- inspect execution status;
- inspect architectural state.

The initial implementation uses a 4-wire SPI slave.

The host interface does not provide a separate HALT-status output pin. Execution status is read through the SPI `STATUS` command.

---

## 2. Physical interface

The host interface uses four SPI signals:

```text
SCLK
CS_N
MOSI
MISO
```

The existing Tiny Tapeout pin allocation is retained.

No additional pin is allocated for HALT or other CPU status.

### 2.1 SPI mode

The slave uses SPI mode 0:

```text
CPOL = 0
CPHA = 0
```

Therefore:

- `SCLK` is low while idle;
- the master changes MOSI on falling edges;
- the slave samples MOSI on rising edges;
- MISO is prepared so that the master samples it on rising edges.

### 2.2 SPI clock frequency

The whole host interface runs in the main `clk` domain. `SCLK` is not used
as a clock: `CS_N`, `SCLK` and `MOSI` are synchronized into the `clk`
domain like any other input, and the wrapper detects `SCLK` edges itself.
`SCLK` must therefore be much slower than `clk`.

Timing requirements, in main-clock periods:

- each `SCLK` high interval and each low interval lasts at least 8 periods;
- `CS_N` is low for at least 8 periods before the first rising `SCLK` edge;
- `CS_N` stays low for at least 8 periods after the final falling edge;
- `CS_N` is high for at least 8 periods between transactions.

This gives a maximum `SCLK` of `f_clk / 16`:

```text
system clock 25 MHz  ->  SCLK <= 1 MHz, 50% duty cycle (provisional)
```

The system clock target (25 MHz) is itself provisional and is set by
static timing analysis of the implemented design. If STA lowers it, the
SCLK limit falls with it. The host must also meet MOSI setup/hold timing
around the rising `SCLK` edge.

These are design limits to verify in simulation and timing analysis, not
measured silicon capabilities.

---

## 3. Frame format

Every host transaction consists of one fixed-length frame:

```text
7 bytes
```

The fixed frame size simplifies the SPI state machine and host software.

### 3.1 Byte layout

One `CS_N` assertion transfers seven bytes. Bytes are sent MSB first;
16-bit values send their high byte first.

| Byte | Host sends on MOSI | Chip sends on MISO |
|---|---|---|
| 0 | Command | Zero |
| 1 | Address | Zero |
| 2 | Data high | Zero |
| 3 | Data low | Zero |
| 4 | Zero | Result code |
| 5 | Zero | Response high |
| 6 | Zero | Response low |

### 3.2 When a command takes effect

- The command executes once, when byte 3 has been received and validated.
- The response is captured at that point and held stable while bytes 4-6
  are shifted out, so a read is coherent even if execution continues.
- Deasserting `CS_N` before byte 3 completes discards the partial command.
- Deasserting `CS_N` after byte 3 does not undo an executed command.
- Extra `SCLK` edges after byte 6 are ignored until `CS_N` is deasserted.
- A command whose response was interrupted must not be repeated
  automatically; the host should check `STATUS` first.

### 3.3 Reserved fields and MISO

Unused request fields (address or data that a command does not use) must
be sent as zero. A nonzero reserved field is rejected with result code
`0x04` (see section 4).

`MISO` is a dedicated output, driven low when `CS_N` is high; it is not a
tri-state bus connection. Connect it to a dedicated host input.

---

## 4. Response and result codes

Each command returns a response within the fixed 7-byte transaction format.

The response includes a result code indicating whether the request was accepted.

| Code | Meaning |
|---|---|
| `0x00` | Success |
| `0x01` | Unknown command |
| `0x02` | Invalid address |
| `0x03` | CPU must be stopped (held) for this command |
| `0x04` | Invalid reserved field |

Rules:

- A rejected command has no side effects, and its response data is zero.
- Checks are made in this order: command, then address, then reserved
  fields, then CPU state. The first failing check gives the result code.
- An out-of-range address is never truncated into the valid range.

---

## 5. CPU execution control

The wrapper provides a `hold` control to the CPU.

`hold` pauses CPU execution without modifying program memory.

Conceptually:

```text
paused = prog_we | hold
```

Normal instruction fetch/execution and DELAY progress are both paused while `paused` is asserted.

`hold` is set by chip reset: after reset the CPU is stopped, and it does
nothing until the host issues `RESTART`. `STATUS` therefore reports "held"
straight after reset, before any program has been loaded.

### 5.1 STOP

`STOP` asserts:

```text
hold = 1
```

The CPU remains in its current architectural state.

While stopped:

- `PC` does not advance;
- instructions do not execute;
- a DELAY countdown does not advance;
- illegal instructions do not trap;
- protocol output registers retain their current values;
- program memory may be written or read by the host.

`STOP` does not reset the CPU.

### 5.2 RESTART

`RESTART` performs a CPU-only restart and resumes execution.

Its required sequence is:

```text
1. CPU is held.
2. Pulse cpu_reset.
3. Release hold.
```

The CPU restarts from its architectural reset state, including:

```text
PC = 0
X = 0
Y = 0
C = 0
```

Program memory is preserved.

`RESTART` is the normal command used after loading a program.

### 5.3 Recommended program-loading sequence

The host should load a program using:

```text
STOP
WRITE_INSTR × required words
optional READ_INSTR verification
RESTART
```

For a complete 64-word image:

```text
STOP
WRITE_INSTR × 64
READ_INSTR × 64       optional verification
RESTART
```

The CPU must never execute a partially loaded program during this sequence.

---

## 6. Program-memory host access

Silverfox contains 64 words of 16-bit program memory.

The host can write and read these words while execution is held.

### 6.1 WRITE_INSTR

`WRITE_INSTR` writes one 16-bit program word.

Request information includes:

```text
address : 6 bits
word    : 16 bits
```

Valid addresses are:

```text
0..63
```

The wrapper generates the existing CPU program-write interface:

```text
prog_we
prog_addr
prog_data
```

A write must not cause CPU execution to advance.

`WRITE_INSTR` is accepted only while the CPU is held. Otherwise it is
rejected with result code `0x03` and memory is unchanged, so a running
program can never be modified in the middle of execution.

### 6.2 READ_INSTR

`READ_INSTR` reads one 16-bit program-memory word.

No second program-memory read port is required.

While `hold` is asserted, the program-memory read address is selected from the host address:

```text
read_addr =
    if hold
    then host_addr
    else pc
```

Thus the existing combinational fetch read port is shared between the CPU and host.

`READ_INSTR` is intended primarily for verifying a program image after loading it.

`READ_INSTR` is accepted only while the CPU is held, because the shared
read port belongs to the PC while the CPU runs. Otherwise it is rejected
with result code `0x03` and returns zero.

---

## 7. STATUS

`STATUS` returns the current execution status of the CPU.

No dedicated HALT-status output pin exists.

The 16-bit status word:

| Bits | Field | Meaning |
|---|---|---|
| 1:0 | `HALT_STATUS` | Same encoding as the CPU's `halt_status`: `00` running, `01` HALT instruction, `10` illegal instruction (`11` is never returned) |
| 2 | `HELD` | 1 while the host holds the CPU (`STOP`, or after chip reset) |
| 7:3 | zero | Reserved |
| 13:8 | `PC` | Current program counter |
| 15:14 | zero | Reserved |

`HELD` and `HALT_STATUS` are independent, so host software can tell apart:

- stopped by the host: `HELD = 1`;
- halted by the program: `HELD = 0`, `HALT_STATUS = 01`;
- trapped on an illegal instruction: `HELD = 0`, `HALT_STATUS = 10`, and
  `PC` points at the illegal word, which `READ_INSTR` can read after `STOP`.

A CPU that was halted and is then stopped reports both, for example
`HELD = 1`, `HALT_STATUS = 01`.

---

## 8. READ_STATE

`READ_STATE` allows the host to inspect architectural CPU state.

The address byte selects the register:

| Selector | Register |
|---|---|
| `0` | `X` |
| `1` | `Y` |
| `2` | `C` |
| `3` | `PINS_OUT` |
| `4` | `PINS_OE` |
| `5` | `UO_OUT` |

Any other selector is rejected with result code `0x02`. The 8-bit value is
zero-extended to 16 bits. `PC` and halt status are read with `STATUS`.

`READ_STATE` is allowed while the CPU runs. It returns the register's
value immediately before the command's execution edge: a snapshot for
inspection, not a guaranteed way to stream data out of a running program.

The initial host data path does not require a mailbox or FIFO.

A receive-oriented protocol program may therefore use the following pattern:

```text
receive one byte into X
HALT
host polls STATUS
host issues READ_STATE
host reads X
```

A dedicated mailbox may be added in a later version if required by workloads.

---

## 9. Pin ownership and masking

Some Tiny Tapeout pins are owned by the host wrapper rather than by Silverfox protocol programs.

### 9.1 Input masking

The following input bits are reserved for the host interface:

```text
ui_in[6:4]
```

These physical values must not be visible to Silverfox programs.

Before the input bank reaches the CPU, reserved host bits are masked to 0:
the CPU sees `ui_in & 0x8F`.

The CPU therefore cannot use `WAIT`, `IN`, `MOV`, or `JMP If_pin` to inspect host-interface activity on these bits.

### 9.2 Output ownership

The wrapper owns:

```text
uo[1]
```

The physical `uo[1]` output is driven by the wrapper and not directly by the CPU's `UO_OUT[1]` architectural state.

Writes by Silverfox instructions to architectural `UO_OUT[1]` must not override the wrapper's physical output.

Other unreserved output bits continue to reflect Silverfox architectural state normally.

---

## 10. Reset and STOP pin behavior

Architectural reset values remain unchanged:

```text
PINS_OUT = 0
PINS_OE  = 0
UO_OUT   = 0
```

The wrapper does not force UART-like protocol outputs to an idle-high value during reset.

For example, if a protocol assigns a UART TX signal to an output-only Silverfox pin, that signal may physically be low immediately after reset.

The protocol program is responsible for establishing its required idle pin state as part of initialization.

While `STOP` / `hold` is asserted:

```text
PINS_OUT holds
PINS_OE  holds
UO_OUT   holds
```

Thus entering host programming mode does not itself toggle protocol outputs.

---

## 11. Input synchronization

External protocol inputs must be synchronized before they are presented to the Silverfox CPU.

The wrapper uses the defined synchronizer stage between physical Tiny Tapeout inputs and the CPU's:

```text
ui_in
uio_in
```

The synchronizer adds latency between a physical input transition and the value observed by an instruction.

The synchronizer depth and the resulting latency in cycles are fixed when
the wrapper is implemented, and must be recorded here then. Not yet
frozen.

The host pins (`CS_N`, `SCLK`, `MOSI`) have their own synchronizers,
separate from the protocol-input path. They reset to `CS_N` high, `SCLK`
low, `MOSI` low. After reset, the wrapper accepts a new frame only once
`CS_N` has been seen high.

Silverfox edge detection operates on the synchronized CPU-side samples, not directly on asynchronous pad values.

`prev_ui` and `prev_uio` continue sampling synchronized inputs while the CPU is held by the host. Therefore a WAIT executed after a host pause compares against recent synchronized input history rather than the input value that existed before the pause.

---

## 12. Command summary

| Code | Command | Address / data | Response |
|---|---|---|---|
| `0x00` | `STATUS` | zero / zero | Status word |
| `0x01` | `STOP` | zero / zero | Zero |
| `0x02` | `RESTART` | zero / zero | Zero |
| `0x10` | `WRITE_INSTR` | 0-63 / instruction word | Zero |
| `0x11` | `READ_INSTR` | 0-63 / zero | Instruction word |
| `0x20` | `READ_STATE` | selector / zero | Register value, zero-extended to 16 bits |

The codes are the same as in the previous host-interface proposal; `STOP`
takes the code of the previous `HALT` command, and the address range grows
from 0-31 to 0-63 with the larger program memory.

---

## 13. Required behavioral properties

The wrapper and CPU integration must verify at least the following:

1. `STOP` prevents PC advancement.
2. `STOP` prevents SET/IN/OUT/MOV/JMP execution.
3. `STOP` freezes `C_NZ_DEC` side effects.
4. `STOP` freezes DELAY countdown.
5. `STOP` suppresses illegal-instruction trapping until execution resumes.
6. Protocol output registers do not change merely because program memory is being loaded.
7. `WRITE_INSTR` modifies only the addressed program word.
8. `READ_INSTR` returns the written word while held.
9. `RESTART` resets CPU architectural state but preserves program memory.
10. Reserved host input pins are not visible to protocol programs.
11. The wrapper-owned output pin cannot be overridden by protocol software.
12. SPI transactions obey the documented mode-0 timing and maximum clock frequency.
13. After chip reset the CPU is held (`STATUS` reports `HELD = 1`) until `RESTART`.
14. `WRITE_INSTR` and `READ_INSTR` are rejected with `0x03`, without side effects, while the CPU is not held.
15. `READ_STATE` rejects selectors above 5 with `0x02`.

---

## 14. Typical host flow

A normal load-and-run transaction sequence is:

```text
power/reset

STOP

for address = 0..63:
    WRITE_INSTR(address, program[address])

for address = 0..63:
    READ_INSTR(address)
    verify returned word

RESTART

poll STATUS

when HALT:
    READ_STATE
```

For a receive demo:

```text
program receives one protocol byte into X
program executes HALT
host observes HALT through STATUS
host reads X through READ_STATE
```

This is sufficient for the initial demonstration without a mailbox.

---

## 15. Future extensions

Possible future host-interface extensions include:

- host-to-core mailbox;
- core-to-host mailbox;
- FIFO access;
- host writes to selected architectural registers;
- trace/debug state;
- execution stepping;
- breakpoint support.

These are not part of host-interface v0.3.