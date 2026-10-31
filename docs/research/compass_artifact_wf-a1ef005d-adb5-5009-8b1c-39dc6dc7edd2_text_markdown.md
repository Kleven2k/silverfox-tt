# silverfox-tt: Plan for the Jane Street Protocol Emulator ASIC Competition

**Your deadline is right: Jan 18, 2027. The quickest way to win is a PIO-style core that runs RP2040 PIO binaries unchanged, plus one or two extensions that do something PIO can't, and a verification story only Hardcaml makes possible. Your bottleneck is getting Hardcaml into the Tiny Tapeout CI, not the ISA, so fix that pipeline first. It takes about 1.5 weeks.**

## TL;DR

- **What counts:** Jane Street says it wants "unique functionality" and "novel approaches to design and verification," and that it will fabricate "the most novel designs." There is no published rubric. The rules are: open source, CMOS5L template, `tiles: 6x4` in `info.yaml`, submit by **Jan 18, 2027** through a form they will post on the blog page later. The tape-out is the March 2027 CMOS5L shuttle, so silicon comes back in Q1 2028: Tiny Tapeout's Chips page lists TTIHP27a with a March 2027 submission deadline and estimated shipping in Q1 2028.
- **Architecture I recommend:** 4 PIO-compatible state machines with 16-bit instructions, sharing a 32×16 flip-flop instruction memory. Each machine has 32-bit shift registers, 4×32-bit TX/RX FIFOs, a 16.8 fractional clock divider and side-set/delay. The host is the Tiny Tapeout board's RP2040, talking over a register-mapped SPI slave with halt/step/exec debug. Protocol I/O uses 8 bidirectional pins, 5 inputs and 7 outputs. By my estimate the core takes about 30% of the ~902k µm² 6x4 core area. Differentiate with a timestamp source and a Manchester/differential output stage, which together make 10BASE-T transmit and a timestamped logic-capture mode possible.
- **Method:** write the protocol programs first, then build an OCaml ISA model and assembler, freeze ISA v1 by Oct 25, run the Hardcaml RTL in lockstep against the model, and prove the decoder and single-step logic with hardcaml_verify. Check the generated Verilog into `src/` so the Tiny Tapeout CI never needs OCaml. Get a full-chip GDS by Nov 8 to learn the real area.

---

## 1. What the rules actually say (checked against the blog post)

| Item | What it says | What it means for you |
|---|---|---|
| Deadline | "Submit your design by **January 18th, 2027**" | Confirmed. Aim to submit by Jan 16. |
| Process/template | IHP 130 nm CMOS5L, `ttihp-verilog-template` cmos5l branch, "Set the tile size in `info.yaml` to 6x4" | Keep 6x4. |
| Area | 6x4 is the maximum today. They are "working on" 8x4 (~30% more) and will email sign-ups if it happens | tt-support-tools issue #189 says 8x4 is currently rejected for `ihp-sg13cmos5l`, because sizes "stop at 8x2 / 6x4". Nothing I found shows it was fixed. **Plan for 6x4.** Treat 8x4 as a bonus. |
| Area guidance | ~200×150 µm per tile, ~0.7 mm² nominal, "about 1K logic cells per tile." SRAM "can be more area-efficient than flip-flops." "Run synthesis early… then run the full place-and-route flow and check timing" | Budget ~24k cells. Measure the real area early. |
| Open source | Required. "feel free to build in public" | Apache-2.0, public repo from day one. |
| Scope | Start with UART, SPI, I2C. Stretch: low-speed USB, 10 Mbit Ethernet. Also mentioned: JTAG, SWD, PS/2, CAN. "Show us anything else your architecture makes possible" | Your 10BASE-T stretch goal lines up with theirs. |
| Explicit non-goal | "The goal isn't to put a UART block, an SPI block, and an I2C block on one die." It must support new protocols *after* fabrication | Protocols have to live in firmware. |
| Verification | They are interested in "formal methods, random constrained tests, AI-assisted verification" and "verification will be an extremely important aspect" | Verification is half the score in practice. Document it as a deliverable. |
| FPGA | "If you have access to an FPGA, consider using it to test your RTL" | Use your Vivado board. |
| Prize | Tape-out on "the **March 2027 CMOS5L shuttle**, subject to the foundry schedule", with chips and dev boards | Tiny Tapeout lists TTIHP27a as a March 2027 submission with estimated shipping in Q1 2028. |
| Submission | "We'll add a final submission form to this page closer to the deadline". Questions go to asic-competition@janestreet.com | Watch the page and your email. |

**Competitive landscape.** At least 10 public entries already exist, and many are PIO clones:
- Metastable: 2 RP2040-PIO-style state machines, a 32-entry shared instruction memory, 16-bit instructions, 8-deep FIFOs and an SPI host.
- nanoPIO: 5 instructions and 32 words of instruction memory.
- Loom: a barrel-threaded design with 4 threads.
- Cycle: capture/replay, with a UART host.
- Sophos: a 6×4 GDS that passed at 40 MHz, plus a USB LS TX bit layer.
- PRISM+TinyQV: SRAM FIFOs, built on an 8x4 fork.
- varun-r-mallya and Protean: two Hardcaml entries.

A plain PIO clone will not stand out. Your edge has to be (a) the verification methodology and (b) one capability the others don't show working, such as 10BASE-T TX.

---

## 2. Phased roadmap (Sep 24, 2026 → Jan 18, 2027, ~16.5 weeks)

| Phase | Dates | Deliverable | Exit gate |
|---|---|---|---|
| **P0: Pipeline** | Sep 24 – Oct 4 | Hardcaml UART TX → generated `src/*.v` → cocotb test → `gds` workflow green at 6x4, with precheck and GL sim. Email Jane Street about 8x4 and what the submission contains. | All 4 CI badges green on a Hardcaml-generated top. Area and slack recorded in the README. |
| **P1: ISA** | Oct 5 – Oct 25 | Protocol programs (UART TX/RX, SPI modes 0–3, I2C master, WS2812, 1-Wire) written *first*. OCaml ISA model and assembler (or pioasm compatibility). Every program passes on the model. ISA spec doc. | **ISA v1 frozen Oct 25.** |
| **P2: RTL** | Oct 26 – Nov 22 | SM, instruction memory, FIFOs, clock divider, pin mux, SPI host, debug. Cyclesim expect tests. Lockstep against the model. | **First full-chip GDS by Nov 8** to measure area and timing. All protocol programs pass on the RTL by Nov 22. |
| **P3: Verify** | Nov 23 – Dec 13 | Random programs vs the model, hardcaml_verify proofs, coverage report, cocotb system tests through the TT pins, GL sim, FPGA bring-up with a logic analyzer. | **Feature freeze Dec 13.** Coverage target met. FPGA demo works. |
| **P4: Stretch** | Dec 14 – Jan 3 | 10BASE-T TX (NLP plus one UDP frame), USB LS TX, optional SRAM buffer, all on a branch | Merge only if every CI job stays green and area stays ≤ ~50% utilisation. |
| **P5: Ship** | Jan 4 – Jan 18 | `docs/info.md` datasheet, verification write-up, demo captures/video, release tag | **RTL freeze Jan 10. Submit by Jan 16.** |

Rule for the whole schedule: every week ends with a green `gds` run on `main`. A design that is 90% done but fails to harden is worth nothing.

---

## 3. Design decisions

| Decision | Recommendation | Why / tradeoff |
|---|---|---|
| **Programmability model** | PIO-style state machines that are **binary-compatible with RP2040 PIO v0**, plus extensions in reserved encodings | You get pioasm, pico-examples and a large existing corpus of programs as free test material. You can also differential-test against a real Pico. Extensions give you the novelty. A general CPU in the style of TI's PRU is more flexible but needs far more area and loses cycle determinism per pin operation. |
| **Protocols** | Must-have: UART TX/RX, SPI master (4 modes), I2C master (open-drain via pindirs). Cheap wins: WS2812, 1-Wire, PS/2, JTAG/SWD bit layers. Stretch: 10BASE-T TX, USB LS TX | Each program is ≤ ~10 instructions on PIO. Skip CAN: bit stuffing, arbitration and CRC eat instruction memory, and it needs a transceiver. |
| **Number of SMs** | **4**, set by a parameter (a Hardcaml functor argument), finalised after the Nov 8 GDS | Full-duplex UART takes 2. UART + I2C + SPI at once takes 4. 10BASE-T takes 1–2 (data + NLP timer). Fall back to 2 if area forces it. |
| **Instruction memory** | **32 × 16-bit, flip-flops, shared, 4 asynchronous read ports** (as PIO). Stretch: 64 entries | Single-cycle fetch for 4 SMs rules out a single-port SRAM unless you barrel-thread, which is Loom's approach. 512 bits of flip-flops is small (see area table). |
| **SRAM** | Not for instructions. Consider a 512×8 or 256×16 macro as a **capture/packet buffer** in P4 only | Much denser, but integrating it means manual placement, a 90° rotation and hand-written PDN work. |
| **Program loading** | **Register-mapped SPI slave** (mode 0, pins oversampled by the system clock through 2-flop synchronisers), with auto-incrementing addresses | The TT board's RP2040 drives it directly, and you get readback, FIFO access and debug. A scan chain is simplest but has no random access and is awkward to verify. A UART bootloader needs only 2 pins but is slow and depends on baud rate. |
| **Debug** | Per-SM enable, halt, single-step, PC readback, force-execute instruction (PIO's `SMx_INSTR`) | Few gates, and it makes bring-up, demos and formal single-step properties much easier. |
| **FIFOs** | 4 × 32-bit TX and RX per SM, joinable into 8 in one direction. Host-visible levels | Matches PIO semantics, so existing programs work. A 32-bit width is needed for WS2812 (24-bit GRB) and for autopull efficiency. |
| **Clock divider** | 16.8 fractional per SM (as PIO), plus an "integer only" mode | Fractional division adds one-cycle jitter. That is fine for UART and I2C, not fine for 10BASE-T/USB. |
| **Clock target** | Constrain at **20 ns (50 MHz)**. Run the demo board at **40 MHz** (10BASE-T) or **48 MHz** (USB LS) | The TT board sets the clock at run time. See the ratio table below. |
| **Datapath width** | 32-bit ISR/OSR/X/Y | Keeps PIO semantics exact. Cutting X/Y to 16 bits saves only a few thousand µm². |
| **Pin mapping** | See below | — |
| **Leave out** | DMA, interrupt controller (just 1 IRQ output pin), PLL/analog, Ethernet RX (needs an analog squelch/receiver), USB FS, CAN, GPIO relocation beyond base+count, the SRAM macro until P4 | Every one of these is either high-risk or outside what the rules ask for. |

**Clock ratios (why 40 or 48 MHz):**

| Target | 40 MHz | 48 MHz | 50 MHz | 60 MHz |
|---|---|---|---|---|
| 10BASE-T half-bit (20 MHz) | 2 ✓ | 2.4 ✗ | 2.5 ✗ | 3 ✓ |
| USB LS bit (1.5 MHz) | 26.67 ✗ | 32 ✓ | 33.3 ✗ | 40 ✓ |
| WS2812 (800 kHz) | 50 ✓ | 60 ✓ | 62.5 | 75 ✓ |
| UART 115200 | 347.2 (frac OK) | 416.7 | 434 | 520.8 |

The Sophos README reports "CMOS5L 6×4 GDS + UART 0x55 GLS + precheck passed on GHA at 25 ns / 40 MHz", so 40 MHz is known to close for this kind of design. 60 MHz serves both stretch goals but probably will not close through the pin crossbar. Tiny Tapeout publishes no pad speed for IHP. Its GPIO spec page gives SKY130 figures of "Maximum output frequency | 33 MHz" and "Maximum input frequency | 66 MHz" with 4 mA drive, so treat 33 MHz output toggling as the practical ceiling until you measure. 10BASE-T only toggles at ≤ 10 MHz fundamental.

**Pin map (proposed):**

| Pins | Use |
|---|---|
| `ui_in[0..2]` | Host SPI: SCK, MOSI, CS_n |
| `ui_in[3..7]` | 5 protocol inputs (GPIO 8–12) |
| `uo_out[7]` | Host SPI MISO |
| `uo_out[6]` | IRQ to host |
| `uo_out[0..5]` | 6 protocol outputs (GPIO 13–18). `uo_out[0..1]` form the complementary pair for 10BASE-T TD+/TD− |
| `uio[0..7]` | 8 bidirectional protocol GPIOs (GPIO 0–7). `uio_oe` is driven by PINDIRS, so I2C/1-Wire open-drain works by "drive 0 or release" |

That is 19 protocol pins in one 32-bit-aligned GPIO space. An SM's pins are base+count windows (PIO's OUT/SET/SIDESET/IN bases). Each output pin gets a fixed-priority OR/priority mux across the SMs.

### Area budget (6x4, CMOS5L)

These are measured anchors. The per-block numbers after them are my own estimates.
- Abagel's 6x4 core area is **902,417 µm²**. Its reset flip-flop (`sg13cmos5l_dfrbpq_1`) is **~49 µm²**, and the average cell is **~13.8 µm²**.
- By Jane Street's "1K cells/tile" guideline, 24k cells × 13.8 µm² ≈ 331k µm² (≈ 37%).
- Flip-flop memory does not scale. 2AMLogic's LibreLane run mapped a **256×16 flip-flop program memory to 378,066 µm²**, about 42% of the whole 6x4 core. A 256×16 IHP SRAM macro is **236.80 × 118.78 µm ≈ 28,127 µm²**, roughly 13× denser.

| Block | Estimate (µm²) | Notes |
|---|---|---|
| Instruction memory 32×16 FF + 4 read muxes | ~50k | 512 bits × 49 µm² ≈ 25k, plus ~6k per 32:1×16 read port |
| Per SM (PC, delay, X/Y, ISR/OSR, counters, divider, config ≈ 220 FF, plus decode/exec) | ~25k | ×4 = ~100k |
| Per-SM FIFOs (2 × 4 × 32 bits) | ~18k | ×4 = ~72k |
| SPI host + register file + debug | ~20k | |
| Pin crossbar / OE logic | ~15k | |
| **Total** | **~260k (~29%)** | Leaves room for extensions before ~50% placement density. The Cycle entry's README says "PL_TARGET_DENSITY_PCT is 50 (routing slack on five metal layers)". |
| Optional: 512×8 SRAM buffer | 26,138 (macro) | 236.80 × 110.38 µm. The 1024×8 macro is proven in silicon on IHP. |

Rule of thumb: FIFOs and instruction memory are the flip-flop hogs, and past ~64×16 bits you need SRAM or a smaller design. The logic itself is cheap.

---

## 4. Block-level architecture

```
                 ┌──────────────── tt_um_kleven2k_silverfox ────────────────┐
 ui_in[0..2] ──► │ Host SPI slave (2FF sync) ─► Register bus (addr/data/we) │
 uo_out[7]  ◄──  │      │                                                   │
                 │      ├─► CTRL: SM enable/halt/step, clkdiv, pin cfg,     │
                 │      │         shift cfg, wrap, side-set cfg              │
                 │      ├─► IMEM 32×16 (FF, 1W / 4R async) ─────┐           │
                 │      ├─► TX FIFO[n] ──► ┌──────────────┐     │           │
                 │      ◄── RX FIFO[n] ◄── │ SM0..SM3     │ ◄───┘ fetch     │
                 │      ├─► FORCE_INSTR[n] │ PC,wrap,delay│                 │
                 │      ◄── DBG: PC/state  │ X,Y,ISR,OSR  │                 │
                 │                         │ shift ctrs   │                 │
                 │  IRQ flags (8, shared) ◄►│ clk-div en   │                 │
                 │  Timestamp ctr (32b) ──►│ decode/exec  │                 │
                 │                         └──────┬───────┘                 │
                 │               pin out/oe/in requests (base+count windows)│
                 │                         ┌──────▼───────┐                 │
                 │                         │ Pin mux +    │ Manchester/diff │
                 │                         │ priority,    │ line coder (opt)│
                 │                         │ 2FF input    │                 │
                 │                         │ synchronisers│                 │
                 │                         └──────┬───────┘                 │
 uio/ui/uo  ◄──► │                           GPIO 0..18                     │
                 └──────────────────────────────────────────────────────────┘
```

Key microarchitecture points:
- **Single-cycle SM**: fetch is combinational from flip-flop instruction memory, then execute, with side-set applied at the start of the instruction. This matches PIO timing. Delay cycles come after it. Stalls (WAIT, blocking PULL/PUSH) hold the PC, and delay does not count down while stalled.
- **Clock enable, not clock division**: each SM advances on `div_en`. There is one clock domain, so no CDC except the pin and SPI synchronisers.
- **Input synchronisers** add 2 cycles of latency. Document this, and make it configurable (bypass) for SPI slave emulation.
- **Pin output priority**: side-set > OUT/SET > MOV, and higher SM number wins, as PIO does. Put this in the spec so the model and RTL agree.

---

## 5. ISA: learning method, PIO deep dive, starter ISA

### Method (in this order)
1. **Write the programs first.** Write UART TX/RX, SPI (CPHA 0/1), I2C, WS2812, 1-Wire and a 10BASE-T sketch in PIO assembly. Count cycles per bit by hand.
2. **Tabulate what each program needs**: pins in and out, counters, conditional branches, FIFO operations, pin directions, timing slack per instruction.
3. **Derive the minimal instruction set.** Any instruction no program uses is a candidate for cutting. Any pattern that costs 3 instructions in a tight loop is a candidate for an extension.
4. **Build the OCaml ISA model and assembler before any RTL.** The model is the spec. Make it a pure `step : state -> inputs -> state * outputs` function so it can run in lockstep, generate random programs and serve as the property oracle.
5. **Freeze the encoding**, then write RTL.

### RP2040/RP2350 PIO: why each piece exists
PIO has 9 instructions. Each PIO block has 32 instruction slots shared by 4 state machines. Each SM has 4-word TX and RX FIFOs, joinable into 8. Every instruction is 16 bits: `[15:13]` opcode, `[12:8]` delay/side-set, `[7:0]` operands. A 5-bit field is shared between delay and up to 5 side-set pins, and optional side-set costs one more bit. Here is the RP2040 encoding (check it against RP2040 datasheet ch. 3.4):

| Op | Encoding `[7:0]` | Why it exists |
|---|---|---|
| **JMP** `000` | cond[7:5] (always, !X, X--, !Y, Y--, X!=Y, PIN, !OSRE), addr[4:0] | The only control flow. `X--` doubles as a loop counter (bit loops) and `PIN` gives a branch on input (e.g. UART stop-bit check). |
| **WAIT** `001` | pol[7], src[6:5] (GPIO, PIN, IRQ), idx[4:0] | Zero-latency synchronisation to an edge or level: UART start bit, SPI slave clock. |
| **IN** `010` | src[7:5] (PINS, X, Y, NULL, ISR, OSR), count[4:0] (0 = 32) | Shifts N bits into the ISR (deserialisation). |
| **OUT** `011` | dst[7:5] (PINS, X, Y, NULL, PINDIRS, PC, ISR, EXEC), count | Serialisation. `OUT PINDIRS` gives open-drain. `OUT PC`/`EXEC` gives data-driven control. |
| **PUSH/PULL** `100` | bit7 = pull, iffull/ifempty[6], block[5] | Hands data to and from the host with backpressure. |
| **MOV** `101` | dst[7:5], op[4:3] (none, invert, bit-reverse), src[2:0] (incl. STATUS) | Register copies. `STATUS` shows FIFO levels. `MOV EXEC` runs an instruction taken from data. |
| **IRQ** `110` | clr[6], wait[5], idx[4:0] | Synchronises SMs with each other and signals the host. |
| **SET** `111` | dst[7:5] (PINS, X, Y, PINDIRS), data[4:0] | Immediate values for pins and counters without using the FIFO. |

Modifiers:
- **Side-set** drives up to 5 pins (or pindirs) in the same cycle as another operation. This is what makes a 2-instruction SPI possible (data out plus clock edge).
- **Delay** `[n]` adds idle cycles after the instruction, which gives exact bit timing without loops.
- **Autopull/autopush** refill the OSR and flush the ISR at a threshold, which removes PULL/PUSH from the inner loop.
- **Wrap** jumps from `wrap_top` to `wrap_target` for free, with no JMP cost.
- **EXEC**: with `OUT EXEC`/`MOV EXEC` the move takes one cycle and the executed instruction runs on the next. The I2C example uses this to put STOP/RESTART sequences into the data stream.

**RP2350 additions** (datasheet §11.1.1):
- Random-access RX FIFO: `mov rxfifo[y], isr` and `mov osr, rxfifo[idx]`, which works like a small register file.
- `irq next/prev` to reach other PIO blocks.
- A `jmppin` wait source.
- `mov pindirs`.
- A version field readable at run time.

The takeaway: PIO spends reserved encodings on features that real programs hit repeatedly, and you should do the same.

### How the canonical programs work
```
; UART TX, 8 cycles/bit (clkdiv = f_clk / (8*baud))
.side_set 1 opt
    pull       side 1 [7]   ; idle high / stop bit, wait for data
    set x, 7   side 0 [7]   ; start bit, bit counter
bitloop:
    out pins, 1             ; LSB first
    jmp x-- bitloop   [6]   ; 1 + 7 = 8 cycles per bit
```
```
; SPI CPHA=0, autopull/autopush at 8 bits: data on OUT pin, SCK on side-set
.side_set 1
    out pins, 1  side 0 [1]
    in  pins, 1  side 1 [1]
```
```
; WS2812: 10 cycles/bit (T1=2, T2=5, T3=3)
.side_set 1
.wrap_target
bitloop:
    out x, 1        side 0 [2]
    jmp !x do_zero  side 1 [1]
do_one:
    jmp bitloop     side 1 [4]
do_zero:
    nop             side 0 [4]
.wrap
```
- **UART RX**: `wait 0 pin 0`, `set x,7 [10]` (to land in mid-bit), a loop of `in pins,1` / `jmp x-- [6]`, then `jmp pin` to check the stop bit.
- **I2C**: SCL on side-set with `side_pindir` (open-drain), SDA via `out pindirs,1`. The host puts START/STOP/RESTART sequences into the TX stream, where they execute through `OUT EXEC`. ACK is sampled with `in pins,1`.

### Other designs worth borrowing from
- **TI PRU**: a 32-bit RISC core at 200 MHz with single-cycle instructions (5 ns) and no pipeline. It has 32 registers. R30 writes outputs and R31 reads inputs directly. TI's ELC slides say it can "detect and react to I/O event within two PRU cycles", and TI app note SPRACE9A says "an external signal change can be detected in as little as 5 nanoseconds". *Lesson:* determinism comes from having no pipeline hazards and direct register-mapped pins. It is a better fit for complex protocol logic, but costs far more area.
- **NXP FlexIO**: fixed-function 32-bit shifters driven by 16-bit timers, with modes such as dual 8-bit baud/bit, automatic start/stop bits and match mode. The KL43 has 4 shifters, 4 timers and 8 pins. An I2C master uses 2 shifters and 2 timers. *Lesson:* hardware start/stop, parity and line coding in the pin path save instructions. That is the idea behind the proposed Manchester coder.
- **Cypress PSoC UDB**: small PLDs paired with an 8-bit datapath and FIFOs. It is configurable but not programmed with instructions. From memory, not verified here.
- **Tiny Tapeout PIO-likes to study**: nanoPIO (5 instructions, 32 words), Metastable (dual PIO-style SMs over SPI, 16-entry GPIO space), Loom (4-thread barrel, every instruction takes exactly one slot).

### Candidate starter ISA (silverfox v1)
**Base: RP2040 PIO v0, bit-exact.** Extensions use only encodings that are reserved on the RP2040:

| Extension | Encoding slot | Purpose |
|---|---|---|
| `IN TIME, n` | IN src `100` (reserved) | Shifts in a free-running 32-bit timestamp. Enables timestamped edge capture, a logic-analyser/protocol-sniffer mode, and timeout measurement. |
| `MOV X, TIME` | MOV src `100` (reserved) | Timeouts and inter-edge timing (UART autobaud, PS/2 timing checks). |
| `WAIT` src `11` = JMPPIN | WAIT src `11` (as RP2350) | Stays compatible going forward. |
| Pin line-coder config (not an opcode) | Per-SM config register: none / complementary pair / Manchester | 10BASE-T TD± from one `OUT` bit per bit time, which halves the instruction and FIFO bandwidth. Also useful for differential test signals. |

Keep RP2350's random-access RX FIFO (`mov rxfifo[y], isr`) as optional, only if area allows. It turns the FIFO into a lookup table, which helps with CRC tables and 1-Wire ROM IDs.

**10BASE-T TX concept:**
- One SM sends NLPs: a pulse of nominally 100 ns (200 ns max) every 16 ms ±8 ms, per IEEE 802.3 §14.3.1.2.1 as quoted in the UNH-IOL 10BASE-Te test suite, counted with `jmp x--` at 40 MHz.
- One SM shifts the preamble, frame and FCS as bits into the Manchester coder, at 2 cycles per half-bit at 40 MHz.
- The host precomputes the CRC32.
- Bandwidth problem: during a frame the SM needs ~1.25 MB/s. An oversampled SPI at SCK ≤ f_clk/8 gives ~0.6 MB/s, so a burst needs either a joined 8-word FIFO plus the SRAM buffer, or a packet short enough for the host to prefill.
- The external network is transmit-only and needs coupling. This is a demo, not a compliant PHY.

### Resources
- **RP2040 datasheet ch. 3 (PIO)**: the primary reference. Read 3.2–3.5 twice. **RP2350 datasheet ch. 11** (§11.1.1 lists what changed).
- **pico-examples `pio/`**: uart_tx/rx, spi, i2c, ws2812, all with .pio sources. **MicroPython `rp2` docs** give a compact summary of instructions and modifiers.
- **rp2040pio-docs**: a PIO emulator with example scripts, useful for semantics corner cases.
- **Raspberry Pi forum threads** on PIO timing (when side-set and pin writes take effect). These edge cases go into your spec.
- **NXP AN5133** (I2C via FlexIO) and **AN5242** (dual SPI via FlexIO). **TI PRU guides** and Ken Shirriff's "PRU tips" post.
- Books: Harris & Harris, *Digital Design and Computer Architecture* (datapath/control). Patterson & Hennessy, *Computer Organization and Design* (encoding tradeoffs). Hennessy & Patterson, *Computer Architecture: A Quantitative Approach*, ch. 1 and Appendix A (instruction set principles: measure first, then encode).

---

## 6. Hardcaml structure

### Toolchain notes
- The template README recommends OxCaml and `opam switch 5.2.0+ox`. It also notes that "the OxCaml version is in a branch named **with-extensions**" in Hardcaml repos. Pin that branch, and record the exact switch and package versions in the repo.
- **Commit the generated Verilog to `src/`** and never have Tiny Tapeout CI build OCaml. The varun-r-mallya entry does this ("checked in so the ASIC flow needs no OCaml"). Add your own GitHub Action that runs `dune build @runtest` and fails if the regenerated Verilog differs from the committed file.

### Layout
```
hw/
  dune-project
  src/            (library silverfox)
    isa.ml        (* encodings shared by model, assembler, RTL *)
    uart_tx.ml  sm.ml  imem.ml  fifo.ml  host_spi.ml  pinmux.ml  top.ml
  model/          (pure OCaml ISA simulator, no Hardcaml dependency)
  asm/            (assembler; parses pioasm syntax + extensions)
  bin/generate.ml (writes ../src/tt_um_kleven2k_silverfox.v)
  test/           (expect tests, lockstep, quickcheck, verify)
src/  test/  info.yaml  docs/   (Tiny Tapeout template, untouched layout)
```

### Interfaces + Always DSL + hierarchy
```ocaml
open! Core
open! Hardcaml
open! Signal

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; start : 'a
    ; data  : 'a [@bits 8]
    ; div_en: 'a              (* one pulse per bit time *)
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t = { tx : 'a; busy : 'a } [@@deriving hardcaml]
end

module State = struct
  type t = Idle | Start | Data | Stop
  [@@deriving sexp_of, compare, enumerate]   (* OxCaml branch may use compare ~localize *)
end

let create scope (i : _ I.t) : _ O.t =
  let ( -- ) = Scope.naming scope in
  let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
  let open Always in
  let sm    = State_machine.create (module State) spec in
  let shreg = Variable.reg spec ~width:8 in
  let bitn  = Variable.reg spec ~width:3 in
  let tx_n  = Variable.reg spec ~width:1 in   (* store inverted: clear -> idle high *)
  compile
    [ sm.switch
        [ Idle,  [ tx_n <-- gnd
                 ; when_ i.start [ shreg <-- i.data; sm.set_next Start ] ]
        ; Start, [ when_ i.div_en [ tx_n <-- vdd; bitn <--. 0; sm.set_next Data ] ]
        ; Data,  [ when_ i.div_en
                     [ tx_n  <-- ~:(lsb shreg.value)
                     ; shreg <-- srl shreg.value ~by:1
                     ; bitn  <-- bitn.value +:. 1
                     ; when_ (bitn.value ==:. 7) [ sm.set_next Stop ] ] ]
        ; Stop,  [ when_ i.div_en [ tx_n <-- gnd; sm.set_next Idle ] ]
        ]
    ];
  { O.tx = ~:(tx_n.value) -- "tx"; busy = ~:(sm.is Idle) }

let hierarchical scope =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ~scope ~name:"uart_tx" create
```
Style rules:
- Use **Always** for control/FSM and plain **Signal** combinators (`mux`, `reg_fb`, `priority_select`) for datapaths.
- Use `Hierarchy.In_scope.hierarchical` for every block you want as a separate Verilog module and a scoped waveform name.
- Name every architecturally visible signal with `--`.
- Parameterise SM count and imem depth through a `Config` module and a functor (`module Make (C : Config) = ...`).
- Share `Isa` types between the model and RTL. For example, derive opcode enums once and use `Enum`-style interfaces for decode.
- Some newer releases change a few API spellings, e.g. `Variable.reg` taking `~enable`, or `let%hw` naming. Check each snippet against the with-extensions branch's `.mli` files.

### Instruction memory (flip-flops, 1 write / N asynchronous reads)
```ocaml
let imem ~clock ~we ~waddr ~wdata ~(pcs : Signal.t array) =
  Signal.multiport_memory 32
    ~write_ports:[| { write_clock = clock; write_address = waddr
                    ; write_enable = we; write_data = wdata } |]
    ~read_addresses:pcs          (* one async read port per SM *)
```
Hardcaml also has `Ram.create` for synchronous-read RAMs, which is the right model if you later wrap an SRAM macro. For the IHP SRAM, instantiate the macro as a black box (`Instantiation.create ~name:"RM_IHPSG13_1P_512x8_c2_bm_bist"`) and keep a behavioural Hardcaml model for simulation.

### Tiny Tapeout top + generation
```ocaml
module Tt_i = struct
  type 'a t = { clk : 'a; rst_n : 'a; ena : 'a
              ; ui_in : 'a [@bits 8]; uio_in : 'a [@bits 8] } [@@deriving hardcaml]
end
module Tt_o = struct
  type 'a t = { uo_out : 'a [@bits 8]; uio_out : 'a [@bits 8]
              ; uio_oe : 'a [@bits 8] } [@@deriving hardcaml]
end
(* inside Top.create: let clear = ~:(i.rst_n) in ... *)

(* bin/generate.ml *)
let () =
  let module C = Circuit.With_interface (Tt_i) (Tt_o) in
  let scope = Scope.create ~flatten_design:false () in
  let circ = C.create_exn ~name:"tt_um_kleven2k_silverfox" (Top.create scope) in
  Rtl.print ~database:(Scope.circuit_database scope) Verilog circ
```
In `hw/test/dune`, add a rule that runs `generate.exe` to a temporary file and then `(diff ../../src/tt_um_kleven2k_silverfox.v gen.v)` in the `runtest` alias. `dune promote` then updates the checked-in file.

### Testbenches
```ocaml
let%expect_test "uart 0x55" =
  let module Sim = Cyclesim.With_interface (Uart_tx.I) (Uart_tx.O) in
  let sim = Sim.create (Uart_tx.create (Scope.create ~flatten_design:true ())) in
  let waves, sim = Hardcaml_waveterm.Waveform.create sim in
  let i = Cyclesim.inputs sim in
  i.data := Bits.of_unsigned_int ~width:8 0x55; i.start := Bits.vdd; i.div_en := Bits.vdd;
  Cyclesim.cycle sim; i.start := Bits.gnd;
  for _ = 1 to 12 do Cyclesim.cycle sim done;
  Hardcaml_waveterm.Waveform.print ~display_width:90 waves;
  [%expect {| |}]   (* dune promote to capture *)
```
- **Expect tests with ASCII waveforms** for every block. These are the review artefact Jane Street itself uses.
- **Hardcaml_step_testbench** for system tests: `spawn` one thread as the SPI host driver, one as the UART/I2C line monitor and one as the scoreboard, all synchronised to the clock. The library now has an effect-based (OCaml 5) interface as well as the monadic one, and the effectful style is simpler for this.
- Use **Hardcaml_verilator** or hardcaml_c for long random regressions.

---

## 7. Verification strategy (make this the showcase)

| Layer | Tool | What it proves / finds |
|---|---|---|
| L0 ISA spec | OCaml model and assembler, expect tests per instruction | The executable spec, including PIO corner cases: side-set timing, stalls vs delay, autopull thresholds, EXEC. |
| L1 Differential vs silicon | Same programs on a real Pico and on your model (and later the FPGA) | Your "PIO-compatible" claim is backed by evidence, not just asserted. Few entries will show this. |
| L2 Lockstep | Cyclesim RTL vs model, compared every cycle on pins and architectural state (via debug outputs) | Microarchitecture bugs. Run on all protocol programs and Quickcheck-generated random programs (constrained: valid jumps, bounded waits, FIFO feeders). |
| L3 Formal | **hardcaml_verify**. SAT combinational equivalence: a spec-style decoder/next-state circuit (written simply, straight from the ISA table) vs the optimised RTL step logic. Bounded model checking for sequential equivalence up to N cycles (e.g. imem load → execute) | Every instruction, for all operand values, not just sampled ones. Note: SAT needs *both* sides as Hardcaml circuits. The pure OCaml model is the oracle for L2, and a "spec circuit" plays that role for L3. |
| L4 Coverage | Functional coverage counters in the OCaml testbench: opcode × operand fields, delay/side-set values, stall causes, FIFO full/empty/join, pin priority conflicts | Publish a coverage table. Target 100% of the ISA cross-product that is legal. |
| L5 AI-assisted | LLM-generated protocol programs and directed tests. The **model is always the oracle**, and generated tests are kept only if they raise coverage | Scales test writing without trusting the AI to check itself. Log prompts and accepted tests. The judges named this topic explicitly. |
| L6 Protocol oracles | cocotb tests via the TT pins. Decode waveforms with an independent decoder (e.g. sigrok-cli decoders) | Checks UART/SPI/I2C correctness against third-party decoders, not your own beliefs. |
| L7 Gate level | Same cocotb suite with `make -B GATES=yes` on the hardened netlist. For IHP, copy `runs/wokwi/.../final/nl/<top>.nl.v` to `test/gate_level_netlist.v`. The Makefile adds `-DGL_TEST -DFUNCTIONAL` | Catches reset/X issues and synthesis mismatches. Runs in the template's `gds` workflow. |
| L8 FPGA | Generated Verilog plus a thin Vivado wrapper, driven by a Pico as host, checked with a logic analyser | Real-pin timing and a demo video. Jane Street suggests this. |

---

## 8. Tiny Tapeout integration

- `info.yaml`:
  - `tiles: "6x4"`, `top_module: "tt_um_kleven2k_silverfox"`, `clock_hz: 40000000` (or 50 MHz), `source_files:` listing the generated `.v`.
  - **Fill in every pinout entry.** The docs workflow fails if they are all empty.
- `src/config.json`: `CLOCK_PERIOD` 20–25. Consider `PL_TARGET_DENSITY_PCT` ≈ 50 for routing headroom.
- `test/Makefile`: list the generated file in `PROJECT_SOURCES`. `test/tb.v` instantiates `tt_um_kleven2k_silverfox`. Reuse your earlier cocotb tests.
- Local iteration: `tt_tool --create-user-config && tt_tool --harden && tt_tool --print-stats`. GitHub `gds` (`tt-gds-action@ihp-cmos5l`) is the flow of record.
- If you add an SRAM:
  - tt-support-tools PR #187 (merged Sep 17, 2026) whitelisted the SRAM/DigiBnd layers so the 1024×8 macro passes precheck.
  - Expect manual macro placement, rotation and PDN work, based on another entrant's report.

---

## 9. Risks

| Risk | Likelihood / impact | Mitigation |
|---|---|---|
| Hardcaml → TT pipeline takes longer than planned (Sophos "missed the week-1 window" with Cyclesim and fell back to Verilog) | Med / High | P0 is only about the pipeline. Generated Verilog is committed. You already have a known-good Verilog UART as a fallback. |
| Area/timing surprises from the crossbar and FIFOs | Med / High | Full GDS by Nov 8. Parameterised SM count and FIFO depth. |
| Not novel enough (≥ 10 public PIO-like entries) | High / High | PIO compatibility plus silicon-differential testing, formal proofs, TIME/line-coder extensions, and a working 10BASE-T TX demo. |
| 8x4 never arrives | High / Low | Design for 6x4 from the start. |
| SRAM integration (placement, PDN, LVS) | Med / Med | Keep it out of the critical path. P4 only. |
| IHP pad speed unknown | Med / Med | 10BASE-T needs ≤ 10 MHz toggling. Keep USB LS optional. |
| Holiday gap (P4) | High / Low | Freeze features Dec 13. P4 is optional. |
| Silicon logistics: Hackster.io reported that chips from an earlier IHP shuttle are yours only "on a two-year loan" and ship only "within the European Union and Switzerland" | Unknown / Low | Norway is outside the EU. Ask asic-competition@janestreet.com early. |

---

## 10. Submission checklist

- [ ] Public GitHub repo `Kleven2k/silverfox-tt`, Apache-2.0 license, README with status table (area, slack, tests).
- [ ] Template: cmos5l branch, `info.yaml` `tiles: "6x4"`, unique `tt_um_` top, `clock_hz`, `source_files`, all pinout fields filled.
- [ ] Generated Verilog committed. `hw/` builds with a pinned OxCaml switch, with instructions to reproduce. CI check that the Verilog is not stale.
- [ ] `test`, `gds` (harden + precheck + GL sim + viewer), `docs` and `fpga` workflows all green on the release tag.
- [ ] `docs/info.md`: how it works, register map, pin map, ISA table, how to test with the TT board's RP2040 (load program, run UART/SPI/I2C/WS2812 demos).
- [ ] Firmware directory: assembler plus `.pio` programs for every claimed protocol, each with a passing test.
- [ ] Verification write-up covering L0–L8, coverage numbers, formal results, AI-assistance log, and known limitations.
- [ ] Host-side driver (MicroPython/C for the TT RP2040) to load and run programs.
- [ ] Demo evidence: FPGA logic-analyser captures, 10BASE-T/NLP capture if done.
- [ ] Area/timing report from the final GDS run: utilisation, WNS at the stated clock.
- [ ] Final submission form (to be posted on the blog page) completed by **Jan 16, 2027**. Confirm receipt by email.

---

## Caveats

- There is no public judging rubric. The "what they value" section reads directly from the blog text ("unique functionality," "novel approaches to design and verification").
- The block-area estimates (per-SM, FIFO, crossbar) are my own. They are extrapolated from measured anchors (49 µm² flip-flop, 13.8 µm² average cell, 902,417 µm² core, 378k µm² for a 256×16 flip-flop memory). Replace them with your Nov 8 numbers.
- The PIO encoding table and program listings are from memory of the RP2040 datasheet and pico-examples. Verify them against the datasheet before freezing the ISA.
- The Hardcaml snippets follow the documented API (Always.State_machine, Hierarchy.In_scope, Cyclesim.With_interface, Waveform). Exact spellings differ between releases, so check them against the with-extensions `.mli` files.
- IHP pad speed and the 8x4 status are unconfirmed as of Sep 24, 2026.