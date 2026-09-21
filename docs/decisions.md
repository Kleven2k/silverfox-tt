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
