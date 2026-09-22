# Roadmap

## Phase 1 - Core ISA skeleton (in progress)
- [x] TT-conformant pin interface (clk/rst_n/ena/ui_in/uo_out/uio_*)
- [x] SET, JMP, HALT opcodes - decode, PC, register file
- [x] hardcaml_test_harness unit test for SET/JMP
- [x] WAIT, IN, OUT, MOV opcodes
- [x] cocotb test suite matching Hardcaml tests

## Phase 2 - UART
- [x] Bit-banged UART TX program (microcode), timed via WAIT
- [x] Bit-banged UART RX program, timed via WAIT + COND_RX_HIGH
- [ ] Verify against a real UART (FPGA loopback or logic analyzer, if available)
- [ ] Document as first entry in protocol-programs.md

## Next milestone - Runtime programming

See [the proposed host interface](host-interface.md) for the target SPI
pin allocation, loading protocol, reset semantics, and acceptance checks.
`Host_bridge` (a crude byte-wide bus on `uio`, strobed via `ui_in[1]`) is a
stand-in for that SPI transport, built to prove reprogrammability through
real pins now rather than waiting on the full transport. It is the actual
TT top level in `src/project.v` today; the real SPI decoder described in
host-interface.md still needs to replace it.

- [x] Writable 32 x 16-bit instruction memory and halt/restart control
- [x] Hardcaml tests: two programs loaded into one core, write protection,
      HALT during WAIT, restart/reset/disable, and one-byte UART RX state
- [x] Pin-driven host loader (`Host_bridge`) wired into `src/project.v` as
      the real TT top level -- no program baked in at synthesis time
- [x] Load a program, restart it, and read PC/X/Y/TX back entirely through
      pins, verified in one cocotb run against the generated Verilog
      (`test/test.py`)
- [ ] Replace `Host_bridge`'s crude byte protocol with the real SPI host
      interface on dedicated pins (CS/SCLK/MOSI/MISO), per host-interface.md
- [ ] Gate-level (post-synthesis) verification of `Host_bridge` and the
      writable-memory core
- [ ] Load and run two *different* programs in the same RTL simulation
      through pins, with no RTL regeneration in between
- [ ] Measure area and timing using the CMOS5L flow

## Phase 3 - SPI
- [ ] SPI controller program (clock generation via toggling pins in microcode)
- [ ] Verify against a known SPI peripheral or loopback

## Phase 4 - I2C
- [ ] I2C controller program (open-drain SDA handling - may need uio_oe logic)
- [ ] Verify against a known I2C peripheral

## Phase 5 - Verification infrastructure
- [ ] hardcaml_verify equivalence checking (golden OCaml model vs generated RTL)
- [ ] Closed-loop AI-assisted test generation (LLM proposes tests -> run -> feed failures back)
- [ ] Coverage tracking / reporting

## Phase 6 - Area/timing closure
- [ ] Run synthesis, check cell area against 24-tile budget
- [ ] Evaluate instruction memory: flip-flops vs SRAM
- [ ] Place-and-route, timing closure at target clock frequency

## Stretch goals (attempt only if core phases land comfortably early)
- [ ] Low-speed USB
- [ ] 10BASE-T Ethernet
- [ ] JTAG / SWD / PS/2 / CAN - pick one if time allows

## Submission
- [ ] Final docs pass (architecture, ISA reference, verification writeup)
- [ ] Submit by Jan 18, 2027
