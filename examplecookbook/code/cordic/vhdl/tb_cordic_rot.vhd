-- ==========================================================================
--  tb_cordic_rot.vhd -- a self-checking VHDL testbench for the CORDIC.
--
--  This is deliberately written the way a VHDL designer writes a testbench:
--  one stimulus process, one checking process, procedures instead of classes,
--  and a golden model built from ieee.math_real.  Read it next to
--  tb_cordic_pkg.sv and tb_cordic_top.sv to see exactly what the class-based
--  structure buys and what it costs.
--
--  Run with:
--      vlib work
--      vcom -2008 cordic_pkg.vhd cordic_rot.vhd tb_cordic_rot.vhd
--      vsim -c -gG_N_RANDOM=300 -do "run -all; quit" tb_cordic_rot
-- ==========================================================================
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

library std;
  use std.textio.all;
  use std.env.finish;

library work;
  use work.cordic_pkg.all;

entity tb_cordic_rot is
  generic (
    -- A generic on a testbench is the VHDL answer to a plusarg: it lets you
    -- change the run without editing the source.  Unlike a plusarg it is
    -- fixed at elaboration: -gG_N_RANDOM=... is given to the elaboration
    -- step, not to the running simulation.
    G_N_RANDOM : natural := 300;
    G_TOL_LSB  : natural := 12;
    G_SEED1    : positive := 7;
    G_SEED2    : positive := 13
  );
end entity tb_cordic_rot;


architecture sim of tb_cordic_rot is

  -- The CORDIC processing gain, K = product sqrt(1 + 2**-2i).
  constant K_GAIN : real := 1.6467602581210656;

  constant CLK_PERIOD : time := 10 ns;

  signal clk    : std_logic := '0';
  signal rst_n  : std_logic := '0';
  signal halt   : boolean   := false;

  signal req_valid : std_logic := '0';
  signal req_ready : std_logic;
  signal req_x     : data_t   := (others => '0');
  signal req_y     : data_t   := (others => '0');
  signal req_theta : angle_t  := (others => '0');

  signal rsp_valid : std_logic;
  signal rsp_ready : std_logic := '0';
  signal rsp_x     : data_t;
  signal rsp_y     : data_t;

  -- The request record.  A VHDL testbench has no mailbox and no dynamic
  -- object, so a transaction is a record and the queue is an array of them
  -- held in a process variable.  This is the single biggest structural
  -- difference from the SystemVerilog version: there, the monitor puts a
  -- class handle into a mailbox and the scoreboard gets it; here, the
  -- monitor and the scoreboard must live in the same process so that they
  -- can share a variable.
  type req_rec_t is record
    x     : integer;
    y     : integer;
    theta : integer;
  end record req_rec_t;

  type req_array_t is array (natural range <>) of req_rec_t;

  constant N_DIRECTED : natural := 8;
  constant N_TOTAL    : natural := N_DIRECTED + G_N_RANDOM;
  constant Q_DEPTH    : natural := 8;   -- outstanding requests

  signal n_checked : natural := 0;
  signal n_failed  : natural := 0;
  signal worst_err : real    := 0.0;

begin

  -- ----------------------------------------------------------------------
  -- Clock.  The classic VHDL idiom.  `halt' stops it so that the simulation
  -- ends by running out of events, which is how a VHDL testbench normally
  -- terminates; std.env.finish is the 2008 alternative and is used below.
  -- ----------------------------------------------------------------------
  clk <= not clk after CLK_PERIOD / 2 when not halt else '0';

  -- ----------------------------------------------------------------------
  -- Device under test
  -- ----------------------------------------------------------------------
  dut : entity work.cordic_rot(rtl)
    generic map (ITER => N)
    port map (
      clk_i       => clk,
      rst_ni      => rst_n,
      req_valid_i => req_valid,
      req_ready_o => req_ready,
      req_x_i     => req_x,
      req_y_i     => req_y,
      req_theta_i => req_theta,
      rsp_valid_o => rsp_valid,
      rsp_ready_i => rsp_ready,
      rsp_x_o     => rsp_x,
      rsp_y_o     => rsp_y
    );

  -- ----------------------------------------------------------------------
  -- Stimulus.
  --
  -- Everything the SystemVerilog driver and generator do together is here in
  -- one process.  Note the two habits that VHDL testbenches rely on and
  -- SystemVerilog replaces with language features:
  --   * driving on the *falling* edge to avoid a race with the DUT, where
  --     SystemVerilog uses a clocking block;
  --   * a `procedure' with signal parameters, where SystemVerilog uses a
  --     class method and a virtual interface.
  -- ----------------------------------------------------------------------
  p_stim : process is

    variable seed1 : positive := G_SEED1;
    variable seed2 : positive := G_SEED2;
    variable r     : real;

    -- uniform() is the standard pseudo-random generator.  There is no
    -- constraint solver: a distribution is something you write yourself.
    impure function rand_int (lo, hi : integer) return integer is
    begin
      uniform(seed1, seed2, r);
      return lo + integer(floor(r * real(hi - lo + 1)));
    end function rand_int;

    procedure send (x, y, theta : integer) is
    begin
      req_x     <= to_signed(x,     DW);
      req_y     <= to_signed(y,     DW);
      req_theta <= to_signed(theta, AW);
      req_valid <= '1';
      -- Hold the request until the DUT takes it.
      loop
        wait until falling_edge(clk);
        exit when req_ready = '1';
      end loop;
      -- The checker snoops the request channel itself, so there is nothing
      -- to log here.
      wait until rising_edge(clk);
      wait until falling_edge(clk);
      req_valid <= '0';
    end procedure send;

  begin
    report "=== cordic_rot testbench (VHDL) ===";
    report "ITER=" & integer'image(N) &
           "  random=" & integer'image(G_N_RANDOM);

    -- reset
    rst_n     <= '0';
    rsp_ready <= '0';
    for i in 0 to 4 loop
      wait until falling_edge(clk);
    end loop;
    rst_n     <= '1';
    rsp_ready <= '1';
    wait until falling_edge(clk);

    -- ---- directed corners --------------------------------------------
    send(X0_UNIT, 0,  0);
    send(X0_UNIT, 0,  PI_EXT);
    send(X0_UNIT, 0, -PI_EXT);
    send(X0_UNIT, 0,  PI_EXT / 2);
    send(X0_UNIT, 0, -PI_EXT / 2);
    send(X0_UNIT, 0,  PI_EXT / 4);
    send(0, X0_UNIT,  PI_EXT / 2);
    send(0, 0,        PI_EXT / 3);

    -- ---- random ------------------------------------------------------
    for i in 0 to G_N_RANDOM - 1 loop
      send(rand_int(-6000, 6000),
           rand_int(-6000, 6000),
           rand_int(-PI_EXT, PI_EXT));
    end loop;

    wait;
  end process p_stim;

  -- ----------------------------------------------------------------------
  -- Checker.
  --
  -- The equivalent of the SystemVerilog monitor and scoreboard, fused into
  -- one process because there is no cheap way to pass a transaction between
  -- two processes in VHDL.
  -- ----------------------------------------------------------------------
  p_check : process is
    -- The pending queue: requests accepted whose result has not come back.
    variable pend   : req_array_t(0 to Q_DEPTH - 1);
    variable p_head : natural := 0;
    variable p_tail : natural := 0;
    variable cur    : req_rec_t;
    variable idx    : natural := 0;
    variable th, xr, yr, x_ref, y_ref, ex, ey : real;
    variable line_v : line;
  begin
    wait until rising_edge(clk) and rst_n = '1';

    while idx < N_TOTAL loop
      wait until rising_edge(clk);

      -- ---- monitor the request channel --------------------------------
      if req_valid = '1' and req_ready = '1' then
        pend(p_tail) := (x     => to_integer(req_x),
                         y     => to_integer(req_y),
                         theta => to_integer(req_theta));
        p_tail := (p_tail + 1) mod Q_DEPTH;
      end if;

      -- ---- monitor the response channel and check ---------------------
      if rsp_valid = '1' and rsp_ready = '1' then
        cur    := pend(p_head);
        p_head := (p_head + 1) mod Q_DEPTH;

        -- the specification, not the implementation
        th    := q_to_real(cur.theta, QA);
        xr    := q_to_real(cur.x,     QF);
        yr    := q_to_real(cur.y,     QF);
        x_ref := K_GAIN * (xr * cos(th) - yr * sin(th));
        y_ref := K_GAIN * (xr * sin(th) + yr * cos(th));

        ex := abs(q_to_real(to_integer(rsp_x), QF) - x_ref) * 2.0 ** QF;
        ey := abs(q_to_real(to_integer(rsp_y), QF) - y_ref) * 2.0 ** QF;

        if ex > worst_err then worst_err <= ex; end if;
        if ey > worst_err then worst_err <= ey; end if;

        if ex > real(G_TOL_LSB) or ey > real(G_TOL_LSB) then
          n_failed <= n_failed + 1;
          write(line_v, string'("MISMATCH #"));
          write(line_v, idx);
          write(line_v, string'("  theta="));
          write(line_v, cur.theta);
          write(line_v, string'("  got x="));
          write(line_v, to_integer(rsp_x));
          write(line_v, string'(" y="));
          write(line_v, to_integer(rsp_y));
          write(line_v, string'("  want x="));
          write(line_v, integer(round(x_ref * 2.0 ** QF)));
          write(line_v, string'(" y="));
          write(line_v, integer(round(y_ref * 2.0 ** QF)));
          writeline(output, line_v);
        end if;

        idx       := idx + 1;
        n_checked <= idx;
      end if;
    end loop;

    -- ---- report ------------------------------------------------------
    wait for 1 ns;
    report "-------------------------------------------------------";
    report "scoreboard: " & integer'image(n_checked) &
           " transactions checked, " & integer'image(n_failed) & " failed";
    report "worst error: " & real'image(worst_err) &
           " LSB (tolerance " & integer'image(G_TOL_LSB) & " LSB)";
    report "-------------------------------------------------------";

    assert n_failed = 0
      report "*** TEST FAILED ***" severity failure;
    report "*** TEST PASSED ***";

    halt <= true;
    finish;
  end process p_check;

  -- ----------------------------------------------------------------------
  -- Watchdog.  Without one a deadlocked DUT gives you a simulation that runs
  -- until you notice.
  -- ----------------------------------------------------------------------
  p_watchdog : process is
  begin
    wait for 200 us;
    report "global timeout: the testbench did not finish"
      severity failure;
  end process p_watchdog;

end architecture sim;
