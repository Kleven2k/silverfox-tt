![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

<div align="center">
<img src="assets/silverfox.png" width="250" height="250">

# Silverfox

### Open Source General-Purpose Protocol Emulator ASIC

![OCaml](https://img.shields.io/badge/OCaml-EC6813?logo=ocaml&logoColor=white)
![Hardcaml](https://img.shields.io/badge/Hardcaml-RTL_generation-black)
![Tiny Tapeout](https://img.shields.io/badge/Tiny%20Tapeout-CMOS5L-blue)
![Python](https://img.shields.io/badge/python-3.11+-blue)

</div>

## What is Silverfox?

Silverfox is a small, reprogrammable CPU for bit-banging hardware
protocols - UART, SPI, and I2C, with USB and Ethernet as stretch
goals. Instead of dedicated protocol peripherals, a compact PIO-inspired
instruction set reads pins, writes pins, counts cycles, and branches on
pin state precisely enough to omplement real protocols in firmware.

Built with [Hardcaml](https://github.com/janestreet/hardcaml) (OCaml) for 
the [Jane Street protocol emulator ASIC competition](https://blog.janestreet.com/protocol-emulator-asic-competition/),
targeting Tiny Tapeout's CMOS5L shuttle.

## Documentation

- [Architecture](docs/architecture.md) — how the core is structured
- [ISA reference](docs/isa.md) — the instruction set
- [Roadmap](docs/roadmap.md) — what's built and what's next
- [Decisions log](docs/decisions.md) — design choices and why

## Development

The Hardcaml/OCaml source lives in `hardcaml/`. See
[docs/architecture.md](docs/architecture.md#toolchain) for toolchain setup.
Generated Verilog lands in `src/project.v`, which feeds Tiny Tapeout's
standard synthesis/GDS pipeline.

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and
cheaper than ever to get your digital and analog designs manufactured on
a real chip. Learn more at https://tinytapeout.com.

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Join the community](https://tinytapeout.com/discord)