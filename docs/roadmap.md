# Roadmap

## Phase 1 - Core ISA skeleton (in progress)
- [x] TT-conformant pin interface (clk/rst_n/ena/ui_in/uo_out/uio_*)
- [x] SET, JMP, HALT opcodes - decode, PC, register file
- [x] hardcaml_test_harness unit test for SET/JMP
- [ ] WAIT, IN, OUT, MOV opcodes
- [ ] cocotb test suite matching Hardcaml tests

## Phase 2 - UART
- [ ] Bit-banged UART TX program (microcode), timed via WAIT
- [ ] Bit-banged UART RX program, timed via WAIT + COND_RX_HIGH
- [ ] Verify aagainst a real UART (FPGA loopback or logic analyzer, if available)
- [ ] Document as first entry in protocol-programs.md

## Phase 3 - SPI
- [ ] SPI controller program (clock generation via toggling pins in microcode)
- [ ] Verify aagainst a known SPI peripheral or loopback

## Phase 4 - I2C
- [ ] I2C controller program (open-drain SDA handling - may need uio_oe logic)
- [ ] Verify aagainst a known I2C peripheral

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