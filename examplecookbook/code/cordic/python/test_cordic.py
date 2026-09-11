"""cocotb testbench for cordic_rot.

The point of this file is that there is no HDL testbench at all: the top level
of the simulation is the DUT itself, and cordic_model.py -- the same module the
SystemVerilog and C++ testbenches are checked against -- is imported directly
and used as a bit-exact golden model.

The same file drives the SystemVerilog RTL and the VHDL RTL, with no change
at all.  Nothing in it is language specific.

    make -f Makefile.cocotb            # VHDL
    make -f Makefile.cocotb SV=1       # SystemVerilog + Verilator
"""

import math
import os
import random
import sys
from collections import deque
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, with_timeout

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cordic_model as m

TOL_LSB = 12


class Txn:
    __slots__ = ("x0", "y0", "theta", "x", "y")

    def __init__(self, x0, y0, theta):
        self.x0, self.y0, self.theta = x0, y0, theta
        self.x = self.y = None

    def __repr__(self):
        return f"Txn(x0={self.x0}, y0={self.y0}, theta={self.theta})"


async def reset(dut, cycles=5):
    dut.rst_ni.value = 0
    dut.req_valid_i.value = 0
    dut.rsp_ready_i.value = 1
    dut.req_x_i.value = 0
    dut.req_y_i.value = 0
    dut.req_theta_i.value = 0
    await ClockCycles(dut.clk_i, cycles)
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)


async def driver(dut, queue, stimulus):
    """Push transactions into the request channel, honouring req_ready_o."""
    for txn in stimulus:
        await RisingEdge(dut.clk_i)
        dut.req_x_i.value = txn.x0 & 0xFFFF
        dut.req_y_i.value = txn.y0 & 0xFFFF
        dut.req_theta_i.value = txn.theta & 0xFFFF
        dut.req_valid_i.value = 1
        while True:
            await RisingEdge(dut.clk_i)
            if dut.req_ready_o.value == 1:
                break
        dut.req_valid_i.value = 0
        queue.append(txn)


async def monitor(dut, queue, results, expected):
    """Sample the response channel on every accepted handshake."""
    while len(results) < expected:
        await RisingEdge(dut.clk_i)
        if dut.rsp_valid_o.value == 1 and dut.rsp_ready_i.value == 1:
            txn = queue.popleft()
            txn.x = dut.rsp_x_o.value.to_signed()
            txn.y = dut.rsp_y_o.value.to_signed()
            results.append(txn)


def scoreboard(results, log):
    """Bit-exact check against cordic_model, plus a float sanity check."""
    errors = 0
    worst = 0.0
    for txn in results:
        ex, ey = m.cordic_rot(txn.x0, txn.y0, txn.theta)
        if (txn.x, txn.y) != (ex, ey):
            errors += 1
            if errors <= 5:
                log.error("%r: got (%d, %d) expected (%d, %d)",
                          txn, txn.x, txn.y, ex, ey)
        fx, fy = m.cordic_float(txn.x0, txn.y0, txn.theta / (1 << m.QA))
        worst = max(worst, abs(txn.x - fx), abs(txn.y - fy))
    return errors, worst


async def run(dut, stimulus):
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    await reset(dut)

    queue, results = deque(), []
    mon = cocotb.start_soon(monitor(dut, queue, results, len(stimulus)))
    drv = cocotb.start_soon(driver(dut, queue, stimulus))
    await with_timeout(drv, 200 * len(stimulus) + 1000, "ns")
    await with_timeout(mon, 200 * len(stimulus) + 1000, "ns")

    errors, worst = scoreboard(results, dut._log)
    dut._log.info("%d transactions, %d bit-exact mismatches, "
                  "worst float error %.2f LSB", len(results), errors, worst)
    assert errors == 0, f"{errors} bit-exact mismatches"
    assert worst <= TOL_LSB, f"worst float error {worst:.2f} > {TOL_LSB} LSB"


@cocotb.test()
async def test_directed(dut):
    """Angles a random generator will not hit."""
    angs = [0.0, math.pi / 2, -math.pi / 2, math.pi / 4, -math.pi / 4,
            1e-4, -1e-4, 3.14, -3.14]
    stim = [Txn(m.X0_UNIT, 0, m.float_to_q(a, m.QA, m.AW)) for a in angs]
    stim += [Txn(0, 0, 0), Txn(6000, -6000, 0)]
    await run(dut, stim)


@cocotb.test()
async def test_random(dut):
    """Constrained random stimulus, seeded from the environment."""
    seed = int(os.environ.get("SEED", "20250905"))
    rng = random.Random(seed)
    lim = m.float_to_q(math.pi, m.QA, m.AW)
    stim = [Txn(rng.randint(-6000, 6000), rng.randint(-6000, 6000),
                rng.randint(-lim, lim)) for _ in range(100)]
    dut._log.info("seed = %d", seed)
    await run(dut, stim)


@cocotb.test()
async def test_sweep(dut):
    """Full sweep of the unit circle: this is the accuracy test."""
    n = 181
    stim = [Txn(m.X0_UNIT, 0,
                m.float_to_q(-math.pi + 2 * math.pi * k / (n - 1),
                             m.QA, m.AW))
            for k in range(n)]
    await run(dut, stim)


@cocotb.test()
async def test_value_semantics(dut):
    """What .value actually gives you on a multi-bit signed port."""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    await reset(dut)
    await run_one(dut, m.X0_UNIT, 0, m.float_to_q(math.pi, m.QA, m.AW))
    v = dut.rsp_x_o.value
    # cocotb 2.x spelling; in 1.x these were v.binstr, v.integer and
    # v.signed_integer.  The trap is the same in both: the plain conversion
    # is UNSIGNED, so a negative result comes back as a large positive one.
    dut._log.info("str(v)         = %s", str(v))
    dut._log.info("int(v)         = %d", int(v))
    dut._log.info("v.to_unsigned()= %d", v.to_unsigned())
    dut._log.info("v.to_signed()  = %d", v.to_signed())
    dut._log.info("model says       = %d",
                  m.cordic_rot(m.X0_UNIT, 0,
                               m.float_to_q(math.pi, m.QA, m.AW))[0])


async def run_one(dut, x0, y0, th):
    txn = Txn(x0, y0, th)
    q, res = deque(), []
    mon = cocotb.start_soon(monitor(dut, q, res, 1))
    drv = cocotb.start_soon(driver(dut, q, [txn]))
    await with_timeout(drv, 5000, "ns")
    await with_timeout(mon, 5000, "ns")
