# SPDX-FileCopyrightText: © 2026 Fredrik
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

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
    """Set the clock period to 10 ns (100 MHz)."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

@cocotb.test()
async def test_project(dut):
    """Verify the default program (SET tx=1 / SET tx=0 / JMP always->0)
    produces a periodic TX waveform: one high cycle out of every three,
    repeating indefinitely. This mirrors the Hardcaml-side SET/JMP test
    in hardcaml/test/isa_test.ml, but runs against the actual generated
    Verilog (src/project.v) via a real HDL simulator, per Tiny Tapeout's
    required test flow -- rather than pinning an exact absolute cycle
    sequence (which proved fragile to simulator-specific timing
    differences during Hardcaml-side test development), this checks the
    periodic *shape* of the waveform, which is what actually matters.
    """
    dut._log.info("Start")

    await start_clock(dut)
    await reset(dut)

    dut._log.info("Sample TX (uo_out bit 0) over multiple periods")

    num_cycles = 12  # 4 full periods of the 3-instruction toggle loop
    tx_trace = []
    for _ in range(num_cycles):
        await ClockCycles(dut.clk, 1)
        tx_trace.append(int(dut.uo_out.value) & 1)

    dut._log.info(f"tx_trace = {tx_trace}")

    # Split into consecutive groups of 3 and check every group is
    # identical -- this proves the waveform is genuinely periodic with
    # period 3, without pinning which absolute cycle the pattern starts
    # on (that phase can differ between simulators/harnesses).
    period = 3
    groups = [tx_trace[i:i + period] for i in range(0, len(tx_trace), period)]
    first_group = groups[0]
    for group in groups[1:]:
        assert group == first_group, (
            f"TX waveform is not periodic with period {period}: "
            f"expected every group to equal {first_group}, got {tx_trace}"
        )

    # Within one period, exactly one cycle should be high (the SET tx=1
    # instruction), matching the program's structure.
    assert sum(first_group) == 1, (
        f"Expected exactly one high cycle per period of {period}, "
        f"got {first_group} (full trace: {tx_trace})"
    )

    dut._log.info("TX waveform confirmed periodic with correct duty cycle")