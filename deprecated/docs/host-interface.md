# Proposed host interface

Status: host protocol proposal. Writable memory and execution control are
implemented as `Programmable_core`, with a synchronous internal interface
and Hardcaml tests. `Host_bridge` (`hardcaml/src/host_bridge.ml`) is the
current TT top level in `src/project.v`: a crude byte-wide bus on `uio`,
strobed via `ui_in[1]`, that loads instructions, restarts, and reads state
back entirely through pins with no RTL regeneration in between -- the
milestone this document originally set out below. It is not the SPI
transport and pin mapping this document specifies; those still need to
replace it. Tests remain in the devcontainer.

## First milestone

Use a fixed SPI peripheral for host control, separate from the programmable
protocol engine. The host can stop execution, read/write 32 instruction
words, restart at address zero, and inspect PC/X/Y. A small fixed loader
remains usable even if the loaded program is wrong or stuck in WAIT.

Start with one received byte followed by HALT, then read X. Reading X from
a continuously running receiver is not a reliable byte-delivery interface:
it may be partway through the next byte. A receive mailbox with valid/ack
and overrun reporting is a later milestone, as is a transmit mailbox.

## Pin allocation

| TT pin | Proposed use | Owner |
| --- | --- | --- |
| `clk` | Main clock; must run during loading | Host/board |
| `rst_n` | Reset core, instruction memory, and host interface | Host/board |
| `ena` | Tiny Tapeout design selection | TT infrastructure |
| `ui_in[0]` | Existing UART RX | Protocol engine |
| `ui_in[3:1]` | Available protocol inputs | Protocol engine |
| `ui_in[4]` | `HOST_CS_N` | Host interface |
| `ui_in[5]` | `HOST_SCLK` | Host interface |
| `ui_in[6]` | `HOST_MOSI` | Host interface |
| `ui_in[7]` | Available protocol input | Protocol engine |
| `uo_out[0]` | Existing UART TX | Protocol engine |
| `uo_out[1]` | `HOST_MISO` | Host interface |
| `uo_out[7:2]` | Available protocol outputs | Protocol engine |
| `uio[7:0]` | Available bidirectional protocol pins | Protocol engine |

The host occupies three inputs and one output; it consumes no bidirectional
pins. Existing UART RX/TX wiring is preserved. SPI and I2C emulation can
later use `uio`, including output-enable control for open-drain operation.

MISO is a dedicated output, driven low when deselected; it is not a
tri-state bus connection. Connect it to a dedicated host input. This pin
allocation requires custom wiring rather than a standard SPI Pmod.
[Tiny Tapeout recommends common pinouts but permits custom allocations.](https://www.tinytapeout.com/specs/pinouts/)

The wrapper owns host pins permanently. Protocol instructions must not
write MISO or change the host pin mapping. The current parallel `MOV`
reads all of `ui_in`; when implementing this interface, mask host inputs
out of that source (`ui_in & 0x8f`) and document this ISA behavior change.
Do not silently feed host traffic into protocol data.

## Clocking and serial framing

Use SPI mode 0: SCLK idles low, input bits are sampled on rising edges,
and output bits change following falling edges. Bytes are MSB first;
16-bit values send their high byte first.

Implement the entire host interface in the main `clk` domain. Synchronize
CS, SCLK, and MOSI before edge detection; do not clock registers directly
from HOST_SCLK. Account for the synchronizer/edge-detector latency when
sampling MOSI and presenting MISO. Protocol RX synchronization is separate.

For the initial implementation, require each SCLK high and low interval,
CS setup before the first rising edge, and CS high between transactions
to last at least eight main-clock periods. Hold CS low for at least eight
main-clock periods after the final falling edge. At a 25 MHz main clock,
use a host SCLK of 1 MHz or slower with a 50% duty cycle. These are proposed
timing limits to verify in simulation and timing analysis, not measured
silicon capabilities. The host must also meet MOSI setup/hold timing.

One CS assertion transfers seven bytes:

| Byte index | Host sends on MOSI | Chip sends on MISO |
| --- | --- | --- |
| 0 | Command | Zero |
| 1 | Address | Zero |
| 2 | Data high | Zero |
| 3 | Data low | Zero |
| 4 | Zero | Result code |
| 5 | Zero | Response high |
| 6 | Zero | Response low |

Execute the command once when byte 3 has been received and validated.
Capture the response at that point and hold it stable while serializing
bytes 4-6. This allows coherent reads even if execution continues.

Deasserting CS before byte 3 completes discards the partial command.
Deasserting it afterwards does not undo an executed command. Ignore extra
clocks after byte 6 until CS is deasserted. Do not automatically repeat a
command whose response was interrupted; query status/readback first.

## Commands

| Code | Command | Address/data | Response |
| --- | --- | --- | --- |
| `0x00` | STATUS | Address and data zero | Status word |
| `0x01` | HALT | Address and data zero | Zero |
| `0x02` | RESTART | Address and data zero | Zero |
| `0x10` | WRITE_INSTR | Address 0-31; data is instruction word | Zero |
| `0x11` | READ_INSTR | Address 0-31; data zero | Instruction word |
| `0x20` | READ_STATE | Address selects register; data zero | Register value |

Result codes: `0x00` success, `0x01` unknown command, `0x02` invalid
address, `0x03` core must be halted, `0x04` invalid reserved field.
Reject invalid commands without side effects; return zero response data.
Validate command, then address, then reserved fields, then running state.
Never truncate out-of-range instruction addresses into the valid range.

STATUS bits: bit 0 is RUNNING, bit 1 is HALTED_BY_INSTRUCTION; all other
bits are zero. HALT clears both bits; executing the ISA's HALT sets bit 1
and clears bit 0. WAIT leaves RUNNING set. Reset and RESTART clear bit 1.

READ_STATE selectors: 0 = PC, 1 = X, 2 = Y, 3 = TX. Zero-extend each value
to 16 bits. State reads are permitted while running and return a snapshot
of the registers immediately before the command's execution edge. This
is for inspection, not a streaming receive-data guarantee.

Instruction reads/writes and RESTART require a halted core. HALT is legal
in either state and acknowledges only after execution is stopped. A host
HALT takes priority over instruction execution on the edge it is accepted,
including when the core is stalled in WAIT. No instruction retires on that
edge. Normal pin values are held when halted.

RESTART preserves instruction memory, sets PC/X/Y to zero, sets TX high
(UART idle), and sets RUNNING. The first instruction executes on the next
main-clock edge. This is a defined restart, not resume-from-current-PC.

## Memory and reset behavior

Start with a 32 x 16-bit register-based memory with combinational read.
This preserves the current one-instruction-per-cycle fetch behavior.
Measure its area before increasing depth or replacing it with a memory
macro; a synchronous memory would require a separate fetch/timing design.

Reset halts the core, clears PC/X/Y, sets TX high, and fills instruction
memory with HALT (`0xe000`). All bidirectional output enables clear to zero;
unused dedicated outputs and MISO clear to zero. Reset therefore destroys
the loaded program. Use RESTART, not reset, to run it again. Resetting TX
high intentionally changes the current reset-to-zero behavior.

A shorter replacement program must explicitly fill its unused tail with
HALT: HALT and RESTART do not erase an older program. The host helper should
always write and verify all 32 words.

When `ena` is low, halt execution, release bidirectional outputs, and
discard the host parser state; preserve instruction memory and core
registers. After re-enabling, require CS high before accepting a new frame,
and require explicit RESTART before execution. Initialize host input
synchronizers to CS high/SCLK low/MOSI low on reset and use the same
CS-high rearm rule after reset. Reset takes priority over every operation.

## Loading example

1. Assert and release reset with CS high and the main clock running.
2. Issue HALT: `01 00 00 00 00 00 00`; check result byte 4 is zero.
3. Write `SET TX, 1` at address 0: `10 00 00 01 00 00 00`.
4. Write HALT at addresses 1-31; for address 1: `10 01 e0 00 00 00 00`.
5. Read address 0: `11 00 00 00 00 00 00`; expect response bytes
   4-6 to be `00 00 01`. Verify the remaining words too.
6. Issue RESTART: `02 00 00 00 00 00 00`. Poll STATUS until RUNNING clears
   and HALTED_BY_INSTRUCTION is set. Read TX using READ_STATE selector 3.
7. Load a second program through the same pins, without reset or RTL
   regeneration, and verify its different behavior.

For a useful end-to-end RX demonstration, load a one-byte UART receiver
that ends in HALT rather than looping. Send a byte on RX, poll STATUS for
HALTED_BY_INSTRUCTION, and read X using `20 01 00 00 00 00 00`. Check every
result code and use bounded host-side polling timeouts.

## Implementation order and acceptance checks

The first step below is implemented in `hardcaml/src/programmable_core.ml`.
Its `halt`, `restart`, and `write_enable` inputs are one-cycle strobes in
the main clock domain. `address` is an eight-bit host instruction address;
the core uses PC for memory reads while running. `read_valid` qualifies
instruction readback, which is zero while running, disabled, reset, or
addressed out of range. PC/X/Y/TX are continuous state outputs for a future
command decoder to snapshot.

`write_accepted` and `restart_accepted` are combinational acceptance
conditions for the upcoming edge, not registered acknowledgements. HALT
wins over write/restart. Simultaneous write and restart requests reject
both. Requests to restart while running are ignored without interrupting
normal execution. The future SPI decoder will turn rejected commands into
the result codes above. This internal interface does not yet synchronize
external pins, mask host pins from MOV, or provide protocol pin routing.

`Isa.execute` supplies a shared decoder for both this module and the ROM
demos. The ROM demos retain their previous reset and automatic execution
behavior. Use `Programmable_core` for the proposed halt-on-reset and
TX-idle-high behavior; it is not yet wired into the TT top level.

1. Separate the TT wrapper from the execution core. Add explicit
   halt/restart/state ports and writable instruction memory. Test those
   ports in Hardcaml before introducing SPI transport. Done, plus a crude
   interim transport (`Host_bridge`, a strobed byte-wide bus on `uio`,
   not SPI) wired into the TT top level to prove pin-driven reprogramming
   end to end while step 2 is still open.
2. Add the synchronized SPI parser, command decoder, and response snapshot.
   Test arbitrary SCLK phase relative to `clk`, partial requests, invalid
   commands/addresses, repeated HALT, reset, and disable/re-enable.
3. Add a host helper that pads to 32 words, loads, verifies, and starts a
   program. Test instruction writes being rejected while running and HALT
   interrupting WAIT. Confirm loading never toggles protocol outputs.
4. In one simulation of one generated RTL design, load and run two distinct
   programs, then load a one-byte RX program and retrieve X through MISO.
   Use only production pins for these assertions, not generated net names.
5. Run synthesis with the writable memory and host interface present, using
   the competition's CMOS5L flow. Record area and timing before adding
   larger memory, streaming mailboxes, or further ISA features.

Deferred: burst loading, checksums, FIFOs, continuous RX/TX delivery,
breakpoints, resume, and wider program memory. The seven-byte transaction
format and pin allocation should be settled before writing the SPI RTL;
the timing limits must be validated with that implementation.
