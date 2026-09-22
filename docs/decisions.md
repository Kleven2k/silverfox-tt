## 18-09-2026 - Try to use Hardcaml instead of hand-written SystemVerilog
Gives me an opportunity to try OCaml's type system for the ISA decode logic 
instead of raw always-blocks. Tradeoff: smaller community/fewer examples than 
plain Verilog, and Hardcaml codegen output is verbose/hard to read directly.

## 18-09-2026 - 16-bit instructions, opcode[15:13]/arg1[12:10]/arg2[9:0]
32-entry program memory (5-bit PC) chosen as a starting point; revisit once
real UART/SPI/I2C programs show whether 32 instructions is enough.

## 18-09-2026 - One-cycle register latency between instruction execute and
## visible output
Confirmed via hardcaml_test_harness: TX pin changes are visible one cycle
after the SET executes, not the same cycle. This is standard synchronous
register behavior. but matters for UART bit-timing calculations later -
need to account for this offset when computing baud-rate cycle counts.

## 19-09-2026 - Tile size 6x4 
Confirmed for now, from other competitors' public repos, shared email 
correspondence with the organizers.

## 20-09-2026 - Never use List.init for side-effecting simulation steps
Core's List.init does not guarantee left-to-right evaluation order of ~f
when it has side effects -- only that the returned list is in index order.
Using it to drive `cycle ()` + sample outputs silently scrambled the
simulation order in isa_test.ml, producing plausible-looking but wrong
traces that took several rounds of waveform/debug-signal digging to catch.
Fix: use an explicit `for i = 1 to n do ... done` loop with a mutable
accumulator for any test that advances simulation and samples state per
cycle. Applies to all future hardcaml_test_harness tests, not just this one.

## 20-09-2926 - Verified IN and WAIT with real assertions (debug-output pattern)
Followed the same debug-print-first-then-assert workflow established for
OUT last session. IN correctly reconstructs a byte from RX bits shifted in
MSB-first over 8 cycles (matches hand-calculated shift sequence exactly).
WAIT correctly holds PC in place while the RX condition is false and falls
through the cycle it becomes true. Both verified via Isa.create_debug
before locking in [%test_eq] assertions -- no bugs found this round,
unlike OUT's earlier List.init incident.

## 21-09-2026 - UART TX: fixed busy-wait loop targeting wrong instruction
First working draft of Uart.tx_program had each bit's JMP X_NOT_ZERO
targeting the SET X instruction (base+1) instead of its own address
(base+2). This reset X to n every iteration instead of decrementing it,
so the loop never exited -- the program got stuck forever on the first
instruction (start bit held low). Caught via pc_trace showing PC pinned
at address 1; fixed by pointing the JMP at itself. Once fixed, pc_trace
showed a clean, uniform 7-cycle-per-block cadence across all 10 bit
periods with zero deviation, confirming both the fix and the framing
logic (start/8 data bits LSB-first/stop) are correct.

Also note: manually eyeballing merged same-value runs in a raw per-cycle
tx_trace is unreliable for verifying bit timing, because the one-cycle
register latency between PC and TX (documented in isa.md) can make
adjacent same-value bits look like they span the wrong number of cycles
even when the underlying timing is exactly correct. Prefer sampling one
value per known bit-block at a fixed offset (as the final UART TX test
does) over inferring boundaries from the raw trace by hand.

## 21-09-2026 - Added a second scratch register (Y) to the ISA
Designing UART RX surfaced a real architectural gap: IN accumulates the
received byte into X across multiple bit periods, but the delay loop
between each bit's IN also needs a register to count down -- and X can't
serve both roles at once without one overwriting the other. Padding each
bit period with hundreds of individual instructions instead of a counted
loop isn't viable either (program memory only holds 32 instructions;
~217 cycles per bit at 25MHz/115200 baud would need far more).

Fix: added Y as a second scratch register, mirroring X exactly (SET
Reg_id.reg_y, JMP Cond.y_not_zero with the same decrement-on-taken-jump
semantics as X_NOT_ZERO). Y is dedicated to delay-loop countdowns; X
stays dedicated to IN/OUT byte accumulation. This mirrors the RP2040
PIO's own X/Y register pair, for the same underlying reason -- a useful
confirmation that the two-register design isn't arbitrary.

All existing tests (SET/JMP/HALT, OUT, IN, WAIT, UART TX) pass unchanged
after the addition, confirming Y is purely additive and doesn't disturb
prior opcode behavior. isa.md's opcode/register tables need updating to
reflect Y once RX is far enough along to document properly.

## 21-09-2026 - Found and fixed a systematic delay-loop timing bug (affected TX too)
Implementing UART RX surfaced a real bug in the delay-loop cycle math used
by both tx_program and rx_program: a "SET reg = n; JMP reg_not_zero ->
self" loop takes n + 2 cycles total (1 for SET, n+1 for JMP's hold), but
both programs were computing n as cycles_per_bit - 1, which only accounts
for part of that overhead and ignores any instruction preceding the
SET/JMP pair (e.g. tx_program's SET TX, rx_program's IN). The result: TX
was actually running ~2 cycles slower per bit than its real target baud
rate the entire time, undetected, because tx_program's own Hardcaml and
cocotb tests only checked internal self-consistency (is the waveform
periodic, with one high bit per period?) -- never checked against an
independently-clocked reference. RX, by design, drives its own timing
from IN/WAIT tracking a transmitter clocked at the *true* cycles_per_bit,
so the accumulated per-bit drift became visible as objectively wrong
received data by bit 5 of the test byte -- a genuine second implementation
catching a bug the first implementation's own tests couldn't see.

Fix: added a general delay_loop_n helper (target cycles, minus 2 for the
SET/JMP pair itself, minus however many instructions precede it) used by
both tx_program and rx_program, replacing the old ad hoc "cycles_per_bit
- 1" everywhere. Verified via pc_trace/x_reg_trace/y_reg_trace debug
output before locking in assertions, same disciplined approach as the
earlier OUT bug. tx_program's existing loop-target-address bug (JMP
pointing at SET instead of itself) had already been fixed in an earlier
session and remained correct through this fix.

Also updated uart_test.ml's TX test, which had hardcoded its own
(also-wrong) cycles_per_block formula rather than importing the real one
from Uart -- now computes it directly as clock_hz / baud_rate, matching
tx_program's corrected timing exactly rather than duplicating the
assumption.

Lesson: a test that only checks a design against its own internal
assumptions (self-consistency) cannot catch a bug in those assumptions
themselves. Only a genuinely independent second calculation, or a real
external timing reference, can. Worth keeping in mind for SPI/I2C and any
other future timing-sensitive protocol work.

Also spent significant time this session chasing what looked like a dune
build-cache bug, before discovering it was simply an incomplete manual
edit (isa.mli's Debug_o block still had 3 fields, and separately had
accidentally been pasted with .ml struct syntax instead of .mli sig
syntax) -- the "stale cache" theory was wrong; always re-verify the
actual file content on disk before assuming a tooling bug, especially
after several manual multi-file edits in a row.

## 21-09-2026 - Considered, prototyped, and deferred a per-instruction delay field
Discussed whether the ISA reads as too close to a "smaller RP2040 PIO"
given the competition brief's explicit "consider what you'd do
differently." Identified that PIO bakes a 5-bit delay into every
instruction, while our SET/JMP delay-loop pattern costs 2-3 instructions
per wait -- directly responsible for rx_program filling all 32
instructions of program memory with zero spare room.

Prototyped a new instruction format (opcode[15:13] / arg1[12:10] /
delay[9:5] / payload[4:0]) adding a built-in 0-31 cycle post-instruction
hold to every opcode, implemented as a delay_counter + pending_pc
mechanism in isa.ml. Verified it compiles and integrates cleanly with the
existing opcode dispatch logic.

Before rewriting tx_program/rx_program against it, worked out the actual
cycle math: max per-instruction delay is 32 cycles (D+1, D up to 31).
Real UART timing needs ~217 cycles/bit and a ~108-cycle half-bit delay --
both far exceeding what a single instruction's delay field can cover, so
a multi-pass loop is still required either way. The redesign would NOT
have reduced RX's per-bit instruction count for this baud rate (still
needs IN + SET Y + JMP, just with fewer/larger-stride loop passes) --
correcting an earlier, overly optimistic claim made mid-discussion that
it would free up roughly a third of RX's instructions.

Decision: deferred the redesign. Reverted isa.ml/isa.mli to the working
Y-register version via `git checkout` (uncommitted, so no working code
was lost). The idea has real merit -- decouples delay-loop register
width from cycle count (Y no longer needs to hold large values), gives
free delays for anything <=32 cycles (likely relevant for SPI/I2C timing
at different clock/baud ratios), and is a genuine, explainable divergence
from PIO worth having in the write-up -- but doesn't solve today's actual
problem (RX at 32/32 instructions, not currently causing any real issue)
and isn't worth a breaking rewrite on speculation alone.

Revisit if: SPI or I2C's timing genuinely needs sub-32-cycle precision
the current loop approach can't express cleanly; a specific program
actually runs out of instruction memory and needs the space back; or
there's spare time near submission specifically to strengthen the
"divergence from PIO" verification-methodology story.
