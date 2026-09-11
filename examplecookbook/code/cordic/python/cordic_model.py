#!/usr/bin/env python3
"""
Bit-exact golden model of the ``cordic_rot`` core, plus the floating point
reference it is checked against.

The model is deliberately written so that every line maps onto one line of
RTL.  It is the single source of truth used by

  * the SystemVerilog testbench (through vectors written by gen_vectors.py),
  * the Verilator C++ testbench (through a generated header),
  * the cocotb testsuite (imported directly).

Number formats
--------------
  x, y      signed, DW  bits, QF  fractional bits   (Q1.14  -> [-2, 2) )
  theta     signed, AW  bits, QA  fractional bits   (Q2.13  -> [-4, 4) )

  internal x, y   signed, IW = DW + GL + GM bits, QF + GL fractional bits
  internal z      signed, IA = AW + GL      bits, QA + GL fractional bits

``GL`` adds precision at the bottom, ``GM`` adds headroom at the top so that
the CORDIC processing gain cannot overflow the datapath.
"""

import math

# --------------------------------------------------------------------------
# Parameters -- keep in step with cordic_pkg.sv / cordic_pkg.vhd
# --------------------------------------------------------------------------
DW = 16          # external x/y width
QF = 14          # external x/y fractional bits
AW = 16          # external angle width
QA = 13          # external angle fractional bits
N = 14           # number of CORDIC micro-rotations
GL = 2           # guard bits added at the LSB side
GM = 2           # guard bits added at the MSB side

IW = DW + GL + GM        # internal x/y width          (20)
IQF = QF + GL            # internal x/y fractional bits (16)
IA = AW + GL             # internal angle width         (18)
IQA = QA + GL            # internal angle frac. bits    (15)

HALF_PI = round(math.pi / 2 * (1 << IQA))     # 51472
PI_INT = round(math.pi * (1 << IQA))          # 102944


def atan_table():
    """arctan(2**-i) in the internal angle format, i = 0 .. N-1."""
    return [round(math.atan(2.0 ** -i) * (1 << IQA)) for i in range(N)]


ATAN = atan_table()


def cordic_gain():
    """The processing gain K = prod sqrt(1 + 2**-2i)."""
    k = 1.0
    for i in range(N):
        k *= math.sqrt(1.0 + 2.0 ** (-2 * i))
    return k


K = cordic_gain()                              # ~1.64676
INV_K = 1.0 / K                                # ~0.60725
X0_UNIT = round(INV_K * (1 << QF))             # 9949, the "unit circle" seed


# --------------------------------------------------------------------------
# Small fixed point helpers
# --------------------------------------------------------------------------
def to_signed(value, width):
    """Interpret the low `width` bits of `value` as two's complement."""
    value &= (1 << width) - 1
    if value & (1 << (width - 1)):
        value -= 1 << width
    return value


def wrap(value, width):
    """Truncate to `width` bits, keeping the two's complement interpretation."""
    return to_signed(value, width)


def asr(value, shift):
    """Arithmetic shift right.  Python's >> on a negative int already floors,
    which is exactly what a hardware arithmetic shift does."""
    return value >> shift


def saturate(value, width):
    """Clamp `value` to the range of a signed `width`-bit number."""
    lo = -(1 << (width - 1))
    hi = (1 << (width - 1)) - 1
    return max(lo, min(hi, value))


def q_to_float(value, frac):
    return value / float(1 << frac)


def float_to_q(value, frac, width):
    return saturate(int(round(value * (1 << frac))), width)


# --------------------------------------------------------------------------
# The bit-exact model
# --------------------------------------------------------------------------
def cordic_rot(x0, y0, theta, trace=False):
    """Rotate the vector (x0, y0) by `theta`.

    Arguments and results are *integers* in the external formats described at
    the top of this file.  Returns (x, y).
    """
    # ---- 1. widen into the internal format -------------------------------
    x = x0 << GL
    y = y0 << GL
    z = theta << GL

    # ---- 2. coarse rotation: bring z into the convergence range ----------
    # The micro-rotation series converges for |z| <= 1.7433 rad, so an angle
    # outside +-pi/2 is first rotated by a whole quadrant.  Rotating by +pi/2
    # maps (x, y) -> (-y, x); rotating by -pi/2 maps (x, y) -> (y, -x).
    if z > HALF_PI:
        x, y, z = -y, x, z - HALF_PI
    elif z < -HALF_PI:
        x, y, z = y, -x, z + HALF_PI

    # ---- 3. the micro-rotation loop --------------------------------------
    for i in range(N):
        dx = asr(y, i)
        dy = asr(x, i)
        if z >= 0:                       # rotate counter-clockwise
            xn, yn, zn = x - dx, y + dy, z - ATAN[i]
        else:                            # rotate clockwise
            xn, yn, zn = x + dx, y - dy, z + ATAN[i]
        x, y, z = wrap(xn, IW), wrap(yn, IW), wrap(zn, IA)
        if trace:
            print(f"  i={i:2d}  x={x:8d} y={y:8d} z={z:8d}")

    # ---- 4. narrow back down, with saturation ----------------------------
    return saturate(asr(x, GL), DW), saturate(asr(y, GL), DW)


def cordic_float(x0, y0, theta):
    """Floating point reference, including the CORDIC processing gain."""
    c, s = math.cos(theta), math.sin(theta)
    return K * (x0 * c - y0 * s), K * (x0 * s + y0 * c)


def sincos(theta_rad):
    """Convenience wrapper: cos/sin of an angle given in radians."""
    theta = float_to_q(theta_rad, QA, AW)
    x, y = cordic_rot(X0_UNIT, 0, theta)
    return q_to_float(x, QF), q_to_float(y, QF)


# --------------------------------------------------------------------------
# Self-check
# --------------------------------------------------------------------------
if __name__ == "__main__":
    print(f"N = {N}, K = {K:.6f}, 1/K = {INV_K:.6f}, X0_UNIT = {X0_UNIT}")
    print(f"HALF_PI = {HALF_PI}, PI = {PI_INT}")
    print("atan table:", ATAN)

    worst = 0.0
    steps = 721
    for k in range(steps):
        ang = -math.pi + 2 * math.pi * k / (steps - 1)
        ang = max(-math.pi, min(math.pi, ang))
        c, s = sincos(ang)
        err = max(abs(c - math.cos(ang)), abs(s - math.sin(ang)))
        worst = max(worst, err)
    print(f"worst |error| over [-pi, pi] = {worst:.6f}"
          f"  ({worst * (1 << QF):.2f} LSB)")
