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
