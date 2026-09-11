-- ==========================================================================
--  cordic_pkg.vhd -- shared declarations for the CORDIC rotator.
--
--  The VHDL counterpart of cordic_pkg.sv.  Read the two side by side: the
--  content is identical, the packaging is not.
--
--  Number formats
--  --------------
--    x, y     signed, DW bits, QF fractional bits   (Q1.14 -> [-2, 2) )
--    theta    signed, AW bits, QA fractional bits   (Q2.13 -> [-4, 4) )
--
--  Internally the datapath is widened by GL bits at the bottom (precision)
--  and GM bits at the top (headroom for the CORDIC processing gain).
--
--  Compile with:  vcom -2008 cordic_pkg.vhd
-- ==========================================================================
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;          -- arctan, round: elaboration-time only

package cordic_pkg is

  -- ----------------------------------------------------------------------
  -- Format constants
  -- ----------------------------------------------------------------------
  constant DW : positive := 16;    -- external x/y width
  constant QF : natural  := 14;    -- external x/y fractional bits
  constant AW : positive := 16;    -- external angle width
  constant QA : natural  := 13;    -- external angle fractional bits
  constant N  : positive := 14;    -- number of micro-rotations
  constant GL : natural  := 2;     -- guard bits at the LSB side
  constant GM : natural  := 2;     -- guard bits at the MSB side

  constant IW  : positive := DW + GL + GM;   -- internal x/y width      (20)
  constant IQF : natural  := QF + GL;        -- internal x/y frac. bits (16)
  constant IA  : positive := AW + GL;        -- internal angle width    (18)
  constant IQA : natural  := QA + GL;        -- internal angle frac.    (15)

  -- ----------------------------------------------------------------------
  -- Subtypes.  A VHDL subtype constrains an existing type; it does not
  -- create a new one, so `data_t' and `signed(15 downto 0)' are freely
  -- interchangeable and the compiler still checks the direction and the
  -- bounds of every assignment.
  -- ----------------------------------------------------------------------
  subtype data_t   is signed(DW - 1 downto 0);
  subtype angle_t  is signed(AW - 1 downto 0);
  subtype idata_t  is signed(IW - 1 downto 0);
  subtype iangle_t is signed(IA - 1 downto 0);

  -- A record is a genuine composite type: it cannot be treated as a bit
  -- vector, and it cannot cross a port boundary of a different type.
  type cordic_req_t is record
    x     : data_t;
    y     : data_t;
    theta : angle_t;
  end record cordic_req_t;

  type cordic_rsp_t is record
    x : data_t;
    y : data_t;
  end record cordic_rsp_t;

  -- ----------------------------------------------------------------------
  -- Elaboration-time constants
  -- ----------------------------------------------------------------------
  constant MAX_DATA : integer :=  2 ** (DW - 1) - 1;   --  32767
  constant MIN_DATA : integer := -2 ** (DW - 1);       -- -32768

  constant HALF_PI_INT : integer := 51472;    -- round(pi/2 * 2**IQA)
  constant PI_INT      : integer := 102944;   -- round(pi   * 2**IQA)
  constant PI_EXT      : integer := 25736;    -- round(pi   * 2**QA)

  -- 2**QF / K, with K = prod sqrt(1 + 2**-2i) the CORDIC processing gain.
  constant X0_UNIT : integer := 9949;

  -- ----------------------------------------------------------------------
  -- The arctangent ROM, computed by the analyser.  ieee.math_real is a
  -- simulation/elaboration library: the function call below is evaluated
  -- once, when the constant is elaborated, and only the resulting integers
  -- reach the netlist.
  -- ----------------------------------------------------------------------
  type atan_rom_t is array (0 to N - 1) of iangle_t;

  function build_atan_rom return atan_rom_t;

  -- A *deferred* constant: the package declares that it exists, the package
  -- body says what its value is.  This is the idiomatic way to initialise a
  -- constant from a function declared in the same package, and it keeps the
  -- elaboration order unambiguous.  SystemVerilog has no equivalent -- a
  -- `localparam' must be given its value where it is declared.
  constant ATAN_ROM : atan_rom_t;

  -- ----------------------------------------------------------------------
  -- Narrow the internal datapath back to the external format, with
  -- saturation.
  -- ----------------------------------------------------------------------
  function sat_narrow (v : idata_t) return data_t;

  -- Testbench helpers: fixed point <-> real.
  function q_to_real (v : integer; f : natural) return real;
  function real_to_q (v : real;    f : natural) return integer;

end package cordic_pkg;


package body cordic_pkg is

  function build_atan_rom return atan_rom_t is
    variable rom : atan_rom_t;
  begin
    for i in 0 to N - 1 loop
      rom(i) := to_signed(
                  integer(round(arctan(2.0 ** (-i)) * 2.0 ** IQA)), IA);
    end loop;
    return rom;
  end function build_atan_rom;

  constant ATAN_ROM : atan_rom_t := build_atan_rom;

  function sat_narrow (v : idata_t) return data_t is
    constant TW : positive := IW - GL;
    variable t  : signed(TW - 1 downto 0);
  begin
    -- Dropping the GL guard bits is an arithmetic shift right, i.e. a plain
    -- slice of the upper bits.  It rounds towards minus infinity, exactly
    -- like the Python golden model.
    t := v(IW - 1 downto GL);
    if t > to_signed(MAX_DATA, TW) then
      return to_signed(MAX_DATA, DW);
    elsif t < to_signed(MIN_DATA, TW) then
      return to_signed(MIN_DATA, DW);
    else
      return resize(t, DW);
    end if;
  end function sat_narrow;

  function q_to_real (v : integer; f : natural) return real is
  begin
    return real(v) / 2.0 ** f;
  end function q_to_real;

  function real_to_q (v : real; f : natural) return integer is
  begin
    return integer(round(v * 2.0 ** f));
  end function real_to_q;

end package body cordic_pkg;
