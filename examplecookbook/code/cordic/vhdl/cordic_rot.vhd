-- ==========================================================================
--  cordic_rot.vhd -- iterative (folded) CORDIC rotator, rotation mode.
--
--  Rotates the vector (x, y) by theta and returns
--
--      x' = K * ( x*cos(theta) - y*sin(theta) )
--      y' = K * ( x*sin(theta) + y*cos(theta) )
--
--  with K ~ 1.6468 the CORDIC processing gain.  Seed the core with
--  x = work.cordic_pkg.X0_UNIT, y = 0 to obtain (cos theta, sin theta).
--
--  One micro-rotation per clock cycle; a transaction takes N + 2 cycles.
--  Request and response use an independent valid/ready handshake.
--
--  Accepted input range: |theta| <= pi.
--
--  Compile with:  vcom -2008 cordic_pkg.vhd cordic_rot.vhd
-- ==========================================================================
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.cordic_pkg.all;

entity cordic_rot is
  generic (
    -- The VHDL generic and the SystemVerilog parameter play the same role.
    -- The difference is that a generic is *typed*: `positive' here rules out
    -- zero and negative values at analysis time.
    ITER : positive := N
  );
  port (
    clk_i       : in  std_logic;
    rst_ni      : in  std_logic;      -- asynchronous, active low

    -- ---- request channel ---------------------------------------------
    req_valid_i : in  std_logic;
    req_ready_o : out std_logic;
    req_x_i     : in  data_t;
    req_y_i     : in  data_t;
    req_theta_i : in  angle_t;

    -- ---- response channel --------------------------------------------
    rsp_valid_o : out std_logic;
    rsp_ready_i : in  std_logic;
    rsp_x_o     : out data_t;
    rsp_y_o     : out data_t
  );
end entity cordic_rot;


architecture rtl of cordic_rot is

  -- ----------------------------------------------------------------------
  -- The state type.  A VHDL enumeration has no encoding of its own: the
  -- synthesis tool picks one (or is told to by an attribute).  In
  -- SystemVerilog you write the base type yourself.
  -- ----------------------------------------------------------------------
  type state_t is (ST_IDLE, ST_ROTATE, ST_DONE);

  signal state_q, state_d : state_t;

  signal x_q, x_d : idata_t;
  signal y_q, y_d : idata_t;
  signal z_q, z_d : iangle_t;
  signal iter_q, iter_d : natural range 0 to ITER - 1;

  -- Stage 1 -- widen and coarse-rotate
  signal x_ext, y_ext, x_load, y_load : idata_t;
  signal z_ext, z_load                : iangle_t;

  -- Stage 2 -- one micro-rotation
  signal x_sh, y_sh, x_rot, y_rot : idata_t;
  signal z_rot, atan_i            : iangle_t;
  signal ccw                      : std_logic;

  constant HALF_PI_S : iangle_t := to_signed(HALF_PI_INT, IA);

begin

  -- ----------------------------------------------------------------------
  -- Stage 1: widen and coarse-rotate.
  --
  -- The micro-rotation series converges only for |z| <= 1.7433 rad, so an
  -- angle outside +-pi/2 is first rotated by a whole quadrant:
  --     +pi/2 : (x, y) -> (-y,  x)
  --     -pi/2 : (x, y) -> ( y, -x)
  -- Both are exact.
  --
  -- `resize' on a `signed' sign-extends; `shift_left' adds the guard bits.
  -- Note how much more explicit this is than the SystemVerilog cast: the
  -- compiler will refuse the assignment if the widths do not match.
  -- ----------------------------------------------------------------------
  x_ext <= shift_left(resize(req_x_i,     IW), GL);
  y_ext <= shift_left(resize(req_y_i,     IW), GL);
  z_ext <= shift_left(resize(req_theta_i, IA), GL);

  p_coarse : process (all) is
  begin
    if z_ext > HALF_PI_S then
      x_load <= -y_ext;
      y_load <=  x_ext;
      z_load <=  z_ext - HALF_PI_S;
    elsif z_ext < -HALF_PI_S then
      x_load <=  y_ext;
      y_load <= -x_ext;
      z_load <=  z_ext + HALF_PI_S;
    else
      x_load <=  x_ext;
      y_load <=  y_ext;
      z_load <=  z_ext;
    end if;
  end process p_coarse;

  -- ----------------------------------------------------------------------
  -- Stage 2: one micro-rotation, purely combinational.
  --
  --     d      = sign(z)
  --     x[i+1] = x[i] - d * (y[i] >> i)
  --     y[i+1] = y[i] + d * (x[i] >> i)
  --     z[i+1] = z[i] - d * atan(2**-i)
  --
  -- `shift_right' on a `signed' is arithmetic by definition -- there is no
  -- way to get it wrong, which is not true of Verilog's `>>' versus `>>>'.
  -- ----------------------------------------------------------------------
  ccw    <= not z_q(IA - 1);            -- z >= 0
  x_sh   <= shift_right(x_q, iter_q);
  y_sh   <= shift_right(y_q, iter_q);
  atan_i <= ATAN_ROM(iter_q);

  x_rot <= x_q - y_sh when ccw = '1' else x_q + y_sh;
  y_rot <= y_q + x_sh when ccw = '1' else y_q - x_sh;
  z_rot <= z_q - atan_i when ccw = '1' else z_q + atan_i;

  -- ----------------------------------------------------------------------
  -- Stage 3: the control FSM.
  --
  -- `process (all)' (VHDL-2008) is the closest thing VHDL has to
  -- `always_comb': the sensitivity list is derived automatically.  What it
  -- does *not* give you is the latch check -- the default assignments below
  -- are still your own responsibility.
  -- ----------------------------------------------------------------------
  p_fsm : process (all) is
  begin
    state_d     <= state_q;
    x_d         <= x_q;
    y_d         <= y_q;
    z_d         <= z_q;
    iter_d      <= iter_q;
    req_ready_o <= '0';
    rsp_valid_o <= '0';

    case state_q is

      when ST_IDLE =>
        req_ready_o <= '1';
        if req_valid_i = '1' then
          x_d     <= x_load;
          y_d     <= y_load;
          z_d     <= z_load;
          iter_d  <= 0;
          state_d <= ST_ROTATE;
        end if;

      when ST_ROTATE =>
        x_d <= x_rot;
        y_d <= y_rot;
        z_d <= z_rot;
        if iter_q = ITER - 1 then
          state_d <= ST_DONE;
        else
          iter_d <= iter_q + 1;
        end if;

      when ST_DONE =>
        rsp_valid_o <= '1';
        if rsp_ready_i = '1' then
          state_d <= ST_IDLE;
        end if;

    end case;
  end process p_fsm;

  -- ----------------------------------------------------------------------
  -- Stage 4: the state registers.
  -- ----------------------------------------------------------------------
  p_regs : process (clk_i, rst_ni) is
  begin
    if rst_ni = '0' then
      state_q <= ST_IDLE;
      x_q     <= (others => '0');
      y_q     <= (others => '0');
      z_q     <= (others => '0');
      iter_q  <= 0;
    elsif rising_edge(clk_i) then
      state_q <= state_d;
      x_q     <= x_d;
      y_q     <= y_d;
      z_q     <= z_d;
      iter_q  <= iter_d;
    end if;
  end process p_regs;

  -- ----------------------------------------------------------------------
  -- Outputs
  -- ----------------------------------------------------------------------
  rsp_x_o <= sat_narrow(x_q);
  rsp_y_o <= sat_narrow(y_q);

  -- ----------------------------------------------------------------------
  -- Built-in checks.  A VHDL `assert' inside a clocked process is the
  -- equivalent of a SystemVerilog immediate assertion.  For the temporal
  -- property below, plain VHDL has no equivalent of `assert property':
  -- either you write the state machine by hand, as here, or you use PSL,
  -- which most simulators accept inside a VHDL comment prefixed `-- psl'.
  -- ----------------------------------------------------------------------
  -- synthesis translate_off
  p_check : process (clk_i) is
    variable prev_valid : std_logic := '0';
    variable prev_x     : data_t    := (others => '0');
    variable prev_y     : data_t    := (others => '0');
    variable prev_theta : angle_t   := (others => '0');
    variable prev_stall : std_logic := '0';
  begin
    if rising_edge(clk_i) and rst_ni = '1' then
      -- input range
      if req_valid_i = '1' and req_ready_o = '1' then
        assert req_theta_i <= to_signed(PI_EXT, AW)
           and req_theta_i >= to_signed(-PI_EXT, AW)
          report "cordic_rot: |theta| > pi (theta = "
                 & integer'image(to_integer(req_theta_i)) & ")"
          severity error;
      end if;

      -- a stalled request must keep its payload stable
      if prev_stall = '1' then
        assert req_x_i = prev_x and req_y_i = prev_y
           and req_theta_i = prev_theta
          report "cordic_rot: request payload changed while stalled"
          severity error;
      end if;

      prev_stall := req_valid_i and not req_ready_o;
      prev_valid := req_valid_i;
      prev_x     := req_x_i;
      prev_y     := req_y_i;
      prev_theta := req_theta_i;
    end if;
  end process p_check;
  -- synthesis translate_on

end architecture rtl;
