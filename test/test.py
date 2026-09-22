# SPDX-FileCopyrightText: © 2026 Fredrik
# SPDX-License-Identifier: Apache-2.0

# project.v now generates Host_bridge (hardcaml/src/host_bridge.ml), the
# pin-driven host loader wrapping Programmable_core -- no protocol program
# is baked into silicon anymore. These tests replace the old fixed-UART
# tests (which asserted TX/RX behavior that no longer exists at reset) with
# the load-a-program-through-pins-and-read-it-back scenario the
# competition brief actually requires. A protocol program (e.g. UART RX,
# via Silverfox_programs.Uart.rx_program) is now something loaded at
# runtime through this byte protocol, not something fixed in the RTL --
# see docs/host-interface.md and test_host_bridge/ for the isolated
# Hardcaml-level and RTL-level development history of this interface.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ReadOnly, NextTimeStep

# Command / State_sel constants, matching hardcaml/src/host_bridge.ml
CMD_HALT = 0x01
CMD_RESTART = 0x02
CMD_WRITE_INSTR = 0x10
CMD_READ_INSTR = 0x11
CMD_READ_STATE = 0x20

SEL_PC = 0
SEL_X = 1
SEL_Y = 2
SEL_TX = 3

# ISA opcode/reg encodings, matching hardcaml/src/isa.ml
OP_SET = 0b000
OP_HALT = 0b111


def encode(opcode, arg1, arg2):
    return ((opcode & 0x7) << 13) | ((arg1 & 0x7) << 10) | (arg2 & 0x3FF)


REG_X = 0b010
REG_Y = 0b100
REG_TX = 0b000
HALT_INSTR = encode(OP_HALT, 0, 0)


async def start_clock(dut):
    cocotb.start_soon(Clock(dut.clk, 40, unit="ns").start())  # 25 MHz


async def reset(dut):
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 1  # RX idles high; BYTE_STROBE (bit 1) idles low
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


def set_byte_strobe(dut, strobe, rx=1):
    dut.ui_in.value = (rx & 1) | ((strobe & 1) << 1)


async def send_byte(dut, byte):
    """Presents one byte on uio_in and pulses BYTE_STROBE (ui_in[1]) for
    one cycle, exactly mirroring what a real host would do driving pins.

    Icarus resolves ClockCycles in Verilog's "active" region, before that
    edge's nonblocking (<=) assignments have settled -- so a value read
    immediately after ClockCycles is one cycle stale (this differs from
    Hardcaml's Cyclesim.cycle, which settles before returning; see
    cocotb/cocotb discussion #3877). Awaiting ReadOnly() after the edge
    moves us past that settle point before returning to the caller, so
    every value this coroutine hands back is this edge's real result.
    ReadOnly forbids writes for the rest of this timestep, so dropping
    the strobe is deferred to NextTimeStep rather than done immediately. """
    dut.uio_in.value = byte & 0xFF
    set_byte_strobe(dut, 1)
    await ClockCycles(dut.clk, 1)
    await ReadOnly()
    await NextTimeStep()
    set_byte_strobe(dut, 0)


async def read_response(dut):
    """byte_index has already advanced to 4 by the end of the committing
    byte's strobe cycle, so the high response byte is on uio_out
    immediately -- see hardcaml/test/host_bridge_test.ml for the same
    reasoning against the Hardcaml-level model."""
    assert int(dut.uio_oe.value) == 0xFF, "uio_oe should drive during response byte 4"
    hi = int(dut.uio_out.value)
    await send_byte(dut, 0)
    assert int(dut.uio_oe.value) == 0xFF, "uio_oe should drive during response byte 5"
    lo = int(dut.uio_out.value)
    await send_byte(dut, 0)
    return (hi << 8) | lo


async def send_command(dut, command, address, data=0):
    await send_byte(dut, command)
    await send_byte(dut, address)
    await send_byte(dut, (data >> 8) & 0xFF)
    await send_byte(dut, data & 0xFF)


async def write_instr(dut, address, data):
    await send_command(dut, CMD_WRITE_INSTR, address, data)
    await read_response(dut)


async def read_instr(dut, address):
    await send_command(dut, CMD_READ_INSTR, address)
    return await read_response(dut)


async def read_state(dut, selector):
    await send_command(dut, CMD_READ_STATE, selector)
    return await read_response(dut)


async def restart(dut):
    await send_command(dut, CMD_RESTART, 0)
    await read_response(dut)


@cocotb.test()
async def test_uio_releases_bus_outside_response_bytes(dut):
    """uio must stay an input (uio_oe == 0) while the host is driving
    command/address/data bytes, only switching to output for the two
    response bytes -- this is what lets a real host share the bus without
    contention, and is exactly the framing invariant host_bridge_test.ml
    checks at the Hardcaml level."""
    await start_clock(dut)
    await reset(dut)

    dut.uio_in.value = CMD_READ_STATE
    set_byte_strobe(dut, 1)
    await ClockCycles(dut.clk, 1)
    await ReadOnly()
    assert int(dut.uio_oe.value) == 0
    await NextTimeStep()
    set_byte_strobe(dut, 0)

    dut.uio_in.value = SEL_PC
    set_byte_strobe(dut, 1)
    await ClockCycles(dut.clk, 1)
    await ReadOnly()
    assert int(dut.uio_oe.value) == 0
    await NextTimeStep()
    set_byte_strobe(dut, 0)


@cocotb.test()
async def test_load_program_restart_and_read_state_back(dut):
    """Loads a small program through real pins via WRITE_INSTR, reads it
    back via READ_INSTR to confirm no RTL/toolchain gap silently drops
    writes, restarts it, and reads PC/X/Y/TX back via READ_STATE -- the
    same end-to-end scenario host_bridge_test.ml proves in Hardcaml, now
    against the actual generated Verilog under Icarus. This is the
    end-to-end proof the competition brief asks for: reprogramming the
    chip through pins with no RTL regeneration in between."""
    await start_clock(dut)
    await reset(dut)

    program = [
        encode(OP_SET, REG_X, 42),
        encode(OP_SET, REG_Y, 7),
        encode(OP_SET, REG_TX, 0),
        HALT_INSTR,
    ]

    for address, data in enumerate(program):
        await write_instr(dut, address, data)

    for address, data in enumerate(program):
        readback = await read_instr(dut, address)
        assert readback == data, f"address {address}: expected {data:#06x}, got {readback:#06x}"

    await restart(dut)

    pc = await read_state(dut, SEL_PC)
    x = await read_state(dut, SEL_X)
    y = await read_state(dut, SEL_Y)
    tx = await read_state(dut, SEL_TX)

    assert pc == 3, f"expected PC halted at address 3, got {pc}"
    assert x == 42, f"expected X == 42, got {x}"
    assert y == 7, f"expected Y == 7, got {y}"
    assert tx == 0, f"expected TX == 0, got {tx}"
