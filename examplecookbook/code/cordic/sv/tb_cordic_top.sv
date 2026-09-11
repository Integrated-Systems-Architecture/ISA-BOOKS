// ===========================================================================
//  tb_cordic_top.sv -- the top level of the SystemVerilog testbench.
//
//  The module has no ports.  Its whole job is to exist so that there is
//  somewhere to put the clock, the interface instance and the DUT, and then
//  to hand a virtual interface to the class-based world in tb_cordic_pkg.
//
//  Run with QuestaSim:
//      vlib work
//      vlog -sv cordic_pkg.sv cordic_if.sv cordic_rot.sv \
//               tb_cordic_pkg.sv tb_cordic_top.sv
//      vsim -c -sv_seed random -do "run -all; quit" tb_cordic_top
//
//  Run with Verilator (no constraints, no coverage -- see Chapter 8):
//    $ verilator --binary --timing -j 0 \
//        cordic_pkg.sv cordic_if.sv cordic_rot.sv \
//        tb_cordic_pkg.sv tb_cordic_top.sv --top-module tb_cordic_top
//      ./obj_dir/Vtb_cordic_top
// ===========================================================================
`timescale 1ns/1ps

module tb_cordic_top;

  import cordic_pkg::*;
  import tb_cordic_pkg::*;

  // -----------------------------------------------------------------------
  // Clock.  `always #5 clk = ~clk' is the whole of VHDL's
  //     clk <= not clk after 5 ns;
  // The variable must be initialised: an uninitialised `logic' is X, and
  // ~X is X, so a testbench whose clock never starts is a classic first-day
  // bug.
  // -----------------------------------------------------------------------
  logic clk = 1'b0;
  always #5 clk = ~clk;          // 100 MHz

  // -----------------------------------------------------------------------
  // The pin bundle and the DUT.
  // -----------------------------------------------------------------------
  cordic_if vif (.clk(clk));

  cordic_rot #(.ITER(N)) u_dut (
    .clk_i       (clk),
    .rst_ni      (vif.rst_n),
    .req_valid_i (vif.req_valid),
    .req_ready_o (vif.req_ready),
    .req_x_i     (vif.req_x),
    .req_y_i     (vif.req_y),
    .req_theta_i (vif.req_theta),
    .rsp_valid_o (vif.rsp_valid),
    .rsp_ready_i (vif.rsp_ready),
    .rsp_x_o     (vif.rsp_x),
    .rsp_y_o     (vif.rsp_y)
  );

  // -----------------------------------------------------------------------
  // The test.
  //
  // Note the shape of it: build, start, stimulate, drain, report, finish.
  // Chapter 7 shows the same six steps written as UVM phases.
  // -----------------------------------------------------------------------
  cordic_env env;

  int unsigned n_random = 200;
  int unsigned seed     = 1;

  initial begin
    // Plusargs are the SystemVerilog answer to a VHDL generic on a
    // testbench: they let you change the run without recompiling.
    void'($value$plusargs("NRANDOM=%d", n_random));
    if ($value$plusargs("SEED=%d", seed)) begin
      // $urandom with an argument seeds the thread's generator.
      void'($urandom(seed));
    end

    $display("=== cordic_rot testbench ===============================");
    $display(" ITER=%0d  DW=%0d.Q%0d  AW=%0d.Q%0d  random=%0d",
             N, DW, QF, AW, QA, n_random);

    env = new(vif);
    env.run();
    env.drv.reset();

    // ---- directed corners first --------------------------------------
    // These are the values a human would think of.  The random stream
    // below is unlikely to hit them exactly, and they are exactly where a
    // quadrant-folding bug lives.
    env.send_directed(angle_t'(X0_UNIT),  16'sd0,  16'sd0);          // 0
    env.send_directed(angle_t'(X0_UNIT),  16'sd0,  angle_t'( PI_EXT));
    env.send_directed(angle_t'(X0_UNIT),  16'sd0,  angle_t'(-PI_EXT));
    env.send_directed(angle_t'(X0_UNIT),  16'sd0,  angle_t'( PI_EXT/2));
    env.send_directed(angle_t'(X0_UNIT),  16'sd0,  angle_t'(-PI_EXT/2));
    env.send_directed(angle_t'(X0_UNIT),  16'sd0,  angle_t'( PI_EXT/4));
    env.send_directed(16'sd0, angle_t'(X0_UNIT),   angle_t'( PI_EXT/2));
    env.send_directed(16'sd0, 16'sd0,              angle_t'( PI_EXT/3));

    // ---- then the random stream ---------------------------------------
    env.send_random(n_random);

    // ---- wait for everything to come back -----------------------------
    // 8 directed + n_random transactions, each taking N+2 cycles plus the
    // random back-pressure.  The generous timeout is a watchdog, not an
    // expectation.
    env.wait_drain(8 + n_random, 200 * (8 + n_random) + 1000);

    env.report();
    $finish;
  end

  // -----------------------------------------------------------------------
  // A global watchdog.  Without one, a deadlocked DUT gives you a simulation
  // that runs until you notice, instead of a test that fails.
  // -----------------------------------------------------------------------
  initial begin
    #5ms;
    $fatal(1, "global timeout: the testbench did not finish");
  end

  // -----------------------------------------------------------------------
  // Waveforms, on demand.
  // -----------------------------------------------------------------------
  initial begin
    if ($test$plusargs("WAVES")) begin
      $dumpfile("tb_cordic.vcd");
      $dumpvars(0, tb_cordic_top);
    end
  end

endmodule : tb_cordic_top
