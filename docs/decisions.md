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

## 22-09-2026 - Found a serious gap: the chip was never actually reprogrammable
A self-review re-reading the competition brief's actual wording caught
something bigger than the ISA-divergence discussion above: "Your chip
should be reprogrammable enough to support new protocols after
fabrication." Isa.hierarchical ~program takes a plain OCaml list and bakes
it into a fixed hardware mux at synthesis time -- there was no way to
change what program runs after the chip is fabricated. What existed was a
chip that could be *fabricated differently* per protocol, not a chip that
could be *reprogrammed* after fabrication -- a materially weaker claim than
the brief asks for, and arguably the single biggest gap in the project at
the time, since it wasn't "what would we do differently" but "the stated
requirement isn't met at all yet."

Fix, built out over the following days: `Program_memory` (writable,
register-based instruction memory, combinational read, reset-to-HALT) and
`Programmable_core` (wraps it with halt/restart/write_enable/address/
state-readback control, all internal synchronous ports) let a host stop the
core, load or read back instructions, and restart it, without RTL
regeneration. Both reuse `Isa.execute`, the same decoder the original ROM
demos use, refactored out of the old `compute` function so the writable
path and the fixed-ROM path share one implementation rather than diverging.
Verified via `hardcaml/test/programmable_core_test.ml` and
`program_memory_test.ml`: two different programs loaded into one core with
a restart between them (proving the memory survives restart and a shorter
second program's stale tail doesn't get executed), write rejection while
running, HALT interrupting a stalled WAIT, and disable/reset behavior.

This alone was not enough to close the gap: `Programmable_core`'s ports
(explicit halt/restart/address/write_data signals, debug state outputs)
don't match Tiny Tapeout's required top-level pin interface, so it could
not become `src/project.v`'s top module directly. `Host_bridge` closes that
last step -- a crude, byte-wide bus on `uio` advanced by a strobe on
ui_in[1], standing in for the real SPI transport in host-interface.md,
but real enough that it IS the generated `tt_um_silverfox_kleven2k` top
level: no protocol program is baked into silicon anymore, and a program can
be loaded, restarted, and read back entirely through real pins. Verified at
the Hardcaml level (`host_bridge_test.ml`) and against the generated
Verilog via cocotb/Icarus (`test/test.py`), then confirmed through a full
gds/precheck/gl_test pass in CI (see the ihp-sg13cmos5l entry below for
what that pass actually needed).

Remaining, tracked in roadmap.md: replace Host_bridge's crude byte protocol
with the real SPI decoder (CS/SCLK/MOSI synchronization, edge detection,
the full command/result-code framing) described in host-interface.md --
in progress as `Spi_bridge`, not yet complete or promoted into project.v.

## 23-09-2026 - Repo was on a stale PDK target (ihp-sg13g2); switched to ihp-sg13cmos5l
The competition blog's template link now points at ttihp-verilog-template's
cmos5l branch, which targets pdk: ihp-sg13cmos5l with tt-gds-action@ihp-cmos5l
-- this repo (generated earlier, from whatever the link resolved to at the
time) was still on ihp-sg13g2 / @ttihp26b throughout .github/workflows/*,
test/Makefile, and info.yaml. Neither name is obviously wrong on its own
(ttihp26b is a real, current TT shuttle tag; ihp-sg13g2 is a real PDK), so
the mismatch went unnoticed until actually diffing this repo against the
current template.

Confirming this took real effort: an AI web-search/fetch tool returned
plausible-looking but factually wrong file contents for a third party's repo
*twice* in the same investigation, momentarily pointing the conclusion the
wrong way (toward "no change needed"). Only pasting the actual file contents
directly, copied by hand from the browser, resolved it -- for a decision
with real fabrication consequences, treat any AI-fetched web content as
unverified until confirmed by directly reading the source yourself.

Fixed by matching the current template exactly, file by file:
- .github/workflows/{gds,docs,fpga}.yaml: pdk: ihp-sg13cmos5l, tag @ihp-cmos5l
- test/Makefile (GATES=yes): sg13cmos5l_io.v / sg13cmos5l_stdcell.v paths
- .devcontainer/Dockerfile: left as PDK=ihp-sg13g2 -- matches the template
  exactly (checked directly), so this is a real, current asymmetry between
  local devcontainer setup and CI, not a leftover to "fix"

This surfaced two further real, PDK-specific gaps once gl_test/precheck
actually ran against ihp-sg13cmos5l:

1. gl_test: "Unknown module type: ihp_mux2 / ihp_dff_r". sg13cmos5l_stdcell.v
   instantiates these as Verilog UDPs defined in a separate file
   (sg13cmos5l_udp.v) that test/Makefile's GATES=yes block didn't include --
   same class of gap the ihp-sg13g2 PDK had (sg13g2_udp.v), independently
   confirmed by another competition entrant hitting the identical issue.
   Fix: add the PDK's *_udp.v file to VERILOG_SOURCES, ahead of *_stdcell.v.

2. precheck (pin check): "Port VGND/VDPWR has too small width: 1.0 < 2.1 um".
   src/config.json's FP_PDN_VPITCH (38.87, tuned for ihp-sg13g2) had no
   FP_PDN_VWIDTH override, so LibreLane generated 1.0um PDN rails against
   this PDK's 2.1um minimum rail width. Fix: FP_PDN_VPITCH 50.0,
   FP_PDN_VWIDTH 2.1, matching the current template exactly.

Lesson: when a competition/toolchain template updates out from under an
existing repo, a wholesale diff against the current template (workflows,
Makefile, config.json, Dockerfile) catches PDK-coupled settings that don't
announce themselves as wrong -- each one only surfaced as a distinct CI
failure, one gate at a time (gds -> precheck -> gl_test), rather than all at
once.

## 15-10-2026 - Restarted the ISA from scratch (v0.3), rewriting the code by hand
The working design on `main` (Host_bridge + Programmable_core, green on
gds/precheck/gl_test for ihp-sg13cmos5l) stays untouched as a fallback. The
restart happens on the `isa-v0.3` branch, with the old code moved to
`deprecated/` as reference.

Why restart rather than patch:
- Delay loops dominated programs: UART RX used 30 of 32 instruction words,
  mostly SET+JMP countdown loops, because the ISA had no direct way to wait
  a number of cycles.
- Loop timing was fragile and easy to get wrong silently (the delay_loop_n
  off-by-two above), since every bit period was hand-assembled from
  instruction costs.
- Loop counting shared registers with data: X/Y had to double as counters.
- Opcode definitions, field positions and execution were tangled together in
  one isa.ml, with bit positions written separately in encode and in the
  RTL's select calls.

What v0.3 changes (spec in docs/isa.md; it went through v0.1 -> v0.3, each
version reviewed against real protocol programs before the next):
- DELAY instruction: exact 1..8192 cycles in one instruction (encoded as
  cycles - 1), replacing countdown loops.
- Dedicated 8-bit loop counter C, so X/Y stay free for data; JMP C_NZ_DEC
  runs a loop body exactly n times and does not underflow at 0.
- JMP can branch on a pin level (UART stop bit, I2C ACK/NACK).
- OUT gets a bank select (UIO/UO) and an open-drain mode for I2C.
- Program memory 64 words (6-bit PC), still flip-flops.
- HALT is SYS 000 = 0xE000 on purpose: program memory resets to that value,
  so empty memory halts instead of sliding through NOPs.
- Rejected on purpose: a general ALU, memory instructions and interrupts.
  Each would cost area and verification effort and weaken cycle
  determinism, and none is needed by UART/SPI/I2C.

Code structure (hardcaml/lib/isa/isa.ml): one module per instruction, each
with its type, encode, decode and a list of every legal instance. Field
positions are defined once in a Field module shared by encode, decode and
(later) the RTL decoder. Bit codes are explicit to_bits/of_bits tables
rather than derived from constructor order, because the encoding has gaps
and per-instruction codes (e.g. the same GPIO registers are 011-101 in SET
but 101-111 in MOV). Instruction types are shaped so illegal instructions
cannot be constructed (no SET_BITS on X, no open-drain on UO, no MOV into an
input bank); numeric ranges go through Make_bounded smart constructors.

Verification so far (hardcaml/test/isa_test.ml), per instruction as it is
added: round trip over every legal instance, a count of legal instances,
reference encodings computed by hand from the bit layout, and illegal words.
SET and WAIT are done. Once all eight instructions exist, the top-level
decode will re-encode and compare to reject reserved bits, and a test over
all 65,536 words will check encode/decode is one-to-one.

AI use (for the write-up): Claude (Anthropic) reviewed each ISA spec version,
pointing out timing bugs in the spec's own examples (each UART bit came out
2 cycles long because loop overhead was not subtracted from the DELAY) and
gaps such as no pin branch and no OUT bank. It also wrote a complete v0.3
isa.ml with tests as a reference implementation (kept in deprecated/). I am
rewriting isa.ml myself, module by module, using that reference to check my
work, so that I understand and own every part of it; the test helpers were
suggested by Claude, the reference encodings are worked out by hand. Earlier
in the project Claude also wrote Host_bridge, the cocotb tests and most of
the PDK-migration fixes, each verified through the full CI flow.

## 17-10-2026 - ISA v0.3 software side complete: encode/decode verified exhaustively
All eight instructions (SET, WAIT, IN, OUT, JMP, MOV, DELAY, SYS) are in
hardcaml/lib/isa/isa.ml, plus the top-level Opcode table and Instruction
type. Instruction.encode adds the opcode once, on top of each instruction's
own operand bits; Instruction.decode reads the opcode, dispatches to that
instruction's decoder, then re-encodes the result and requires an exact match
with the original word. That last step rejects nonzero reserved bits for every
instruction at once, without listing reserved fields per instruction.

Verification (hardcaml/test/isa_test.ml, 33 tests, all passing):
- Per instruction: round trip over every legal instance, a count of legal
  instances, reference encodings, and illegal words where the instruction's
  own decoder must reject them (reserved SET destinations, SET_BITS on X/Y/C,
  open-drain on UO, MOV into an input bank, reserved JMP/SYS codes).
- Top level: round trip over all instructions, one full-word reference
  encoding per opcode (HALT = 0xE000, DELAY 1 = 0xC000, ...), reserved-bit
  words rejected (e.g. 0x8040, a JMP ALWAYS with a pin bit set), and an
  exhaustive pass over all 65,536 words. Every word either fails to decode
  or decodes to an instruction that re-encodes to exactly that word, and the
  number of legal words (14,674) equals the number of legal instructions, so
  the encoding is one-to-one.

Why both kinds of test are needed: a round trip only proves encode and
decode agree with each other; it cannot catch both being wrong the same way
(e.g. a field at the wrong bit position in both). The reference encodings
were computed by hand from the bit layouts in docs/isa.md, independently of
the code, so they check the code against the spec. Writing them out also
caught a mistake in the hand calculation itself (0x1406 vs the correct
0x1407), which is the point: a disagreement means either the code or the
calculation is wrong, and both get rechecked. Reference cases were chosen so
every field is non-zero at least once, since a field that is always zero in
the references could sit at the wrong position unnoticed.

Lesson from JMP: a per-instruction decoder ignores bits its instruction does
not use, so "ALWAYS with a pin bit set" decodes fine at that level. That
test failed when first placed in the JMP section; it belongs at the top
level, where the re-encode check rejects it. Each layer of tests should
check only what that layer is responsible for.

AI use in this phase: I wrote each instruction module myself, using Claude's
reference isa.ml (deprecated/) as an answer key to compare against, and
Claude explained the OCaml and encoding concepts I had not used before
(Field get/put and masks, functors and private types, Or_error/let%bind,
variants vs records) and reviewed each step. The test helpers and the test
structure were suggested by Claude; the reference encodings were computed by
hand by me.

Next: bring docs/isa.md up to date with every instruction's bit layout, then
write a pure OCaml reference model (a step function over PC, X, Y, C, pins and
the delay counter) that defines what each instruction does, as the oracle for
lockstep testing of the Hardcaml RTL core.
