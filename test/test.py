# SPDX-FileCopyrightText: © 2026 Fredrik
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

# --- Helpers ---
async def reset(dut):
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1


async def start_clock(dut):
    """Set the clock period to 10 ns (100 MHz simulated clock).
    Note: this is the *simulation* clock speed cocotb drives the DUT
    with -- unrelated to the 25 MHz clock_hz baked into the UART TX
    program's own bit-timing math (cycles_per_bit was computed against
    25 MHz at generation time, so the design's *behavior* -- how many
    clock edges per bit -- is fixed regardless of how fast we simulate
    those edges)."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())


@cocotb.test()
async def test_uart_tx_framing(dut):
    """Verify UART TX (0x55, 8-N-1) against the real generated Verilog,
    at the actual target timing (25 MHz clock, 115200 baud ->
    cycles_per_bit = 217). Mirrors the Hardcaml-side uart_test.ml
    assertion, but runs against src/project.v via Icarus Verilog, per
    Tiny Tapeout's required test flow.

    Samples one value per bit-block at a fixed offset (well clear of
    the block's edges), rather than inferring bit boundaries from
    merged runs in a raw per-cycle trace -- see decisions.md for why
    that approach proved unreliable during Hardcaml-side development.
    """
    dut._log.info("Start")

    await start_clock(dut)
    await reset(dut)

    byte_sent = 0x55
    clock_hz = 25_000_000
    baud_rate = 115_200
    cycles_per_bit = clock_hz // baud_rate  # 217
    # Each TX bit block (SET TX; SET X; JMP loop) is designed to take
    # exactly cycles_per_bit cycles total -- see Uart.delay_loop_n in
    # hardcaml/src/programs/uart.ml, and decisions.md for the timing
    # bug this fixed (the old n = cycles_per_bit - 1 formula undercounted
    # the SET/JMP loop's own overhead).
    cycles_per_block = cycles_per_bit
    sample_offset = 10  # comfortably inside the block, past the edge

    num_bits = 10  # 1 start + 8 data + 1 stop

    sampled_bits = []
    for _bit_index in range(num_bits):
        for cycle_in_block in range(1, cycles_per_block + 1):
            await ClockCycles(dut.clk, 1)
            if cycle_in_block == sample_offset:
                sampled_bits.append(int(dut.uo_out.value) & 1)

    dut._log.info(f"sampled_bits = {sampled_bits}")

    data_bits = [(byte_sent >> i) & 1 for i in range(8)]
    expected_bits = [0] + data_bits + [1]

    assert sampled_bits == expected_bits, (
        f"UART TX framing mismatch: expected {expected_bits}, "
        f"got {sampled_bits}"
    )

    dut._log.info("UART TX framing confirmed correct against generated Verilog")

@cocotb.test()
async def test_uart_rx_receives_byte(dut):
    """Verify UART RX agains the real generated Verilog: drives a
    simulated 8-N-1 UART frame (start=0, 8 data bits LSB-first, stop=1)
    onto ui_in[0], then reads the received byte directly from the core's
    internal X register (Hardcaml-generated net name signal_reg_1 inside
    the silverfox_isa sub-module, confirmed by tracing its driving logic
    -- see decisions.md) since the production pin interface does not
    expose the received byte on any output pin. This mirrors what
    Isa.create_debug does for the Hardcaml-side test, using cocotb's
    hierarchical signal access instead.
    """
    dut._log.info("Start")

    await start_clock(dut)
    await reset(dut)

    byte_to_receive = 0b1011_0010
    clock_hz = 25_000_000
    baud_rate = 115_200
    cycles_per_bit = clock_hz // baud_rate

    data_bits = [(byte_to_receive >> i) & 1 for i in range(8)]
    frame = [0] + data_bits + [1]   # start, 8 data bits LSB-first, stop

    # Line idles high before the frame starts.
    dut.ui_in.value = 1
    await ClockCycles(dut.clk, 5)

    for bit in frame:
        dut.ui_in.value = bit
        await ClockCycles(dut.clk, cycles_per_bit)

    # A little settling time after the frame ends before reading X.
    await ClockCycles(dut.clk, 5)

    x_reg_path = dut.user_project.silverfox_isa.signal_reg_1
    received = int(x_reg_path.value)

    dut._log.info(f"received = {received:#04x} (expected {byte_to_receive:#04x})")

    assert received == byte_to_receive, (
        f"UART RX mismatch: expected {byte_to_receive:#04x}, "
        f"got {received:#04x}"
    )

    dut._log.info("UART RX byte confirmed correct against generated Verilog")