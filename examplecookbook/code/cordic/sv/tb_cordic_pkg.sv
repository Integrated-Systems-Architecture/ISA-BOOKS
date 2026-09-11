// ===========================================================================
//  tb_cordic_pkg.sv -- a layered, class-based testbench without UVM.
//
//  Everything UVM gives you is here in about 350 lines: a transaction, a
//  stimulus generator, a driver, a passive monitor, a scoreboard with a
//  reference model, a coverage collector and an environment that wires them
//  together.  Nothing is imported from a library; the only reason UVM exists
//  is that it standardises *these* names and adds configuration, factory
//  overrides and phasing on top.
//
//  Read this file before Chapter 7.  UVM will then look like what it is: the
//  same six boxes with a base class in front of each one.
// ===========================================================================
`timescale 1ns/1ps

// ---------------------------------------------------------------------------
// Portability shim.
//
// The natural way to reach a clocking block from a class is
// `vif.drv_cb.req_valid <= v'.  Verilator 5.020 cannot do that.  A modport
// that exports a clocking block is rejected outright, and -- worse -- a
// non-blocking assignment through a virtual interface to a clocking-block
// output is silently DROPPED: the write never happens and no warning is
// issued.  See Chapter 8 for the ten-line test case that demonstrates it.
//
// Rather than write the testbench twice, the four access points are hidden
// behind four macros.  In any IEEE 1800 simulator they expand to the clocking
// block, with its Preponed sampling and its output skew.  Under Verilator
// they expand to the raw interface signals plus an explicit clock edge, which
// loses the skew but keeps the testbench runnable.
//
// This is what portability actually costs, and it is worth seeing once.
// ---------------------------------------------------------------------------
`ifdef VERILATOR
  `define CB_DRV       vif
  `define CB_MON       vif
  `define EDGE_DRV     @(posedge vif.clk)
  `define EDGE_MON     @(posedge vif.clk)
`else
  `define CB_DRV       vif.drv_cb
  `define CB_MON       vif.mon_cb
  `define EDGE_DRV     @(vif.drv_cb)
  `define EDGE_MON     @(vif.mon_cb)
`endif

package tb_cordic_pkg;

  import cordic_pkg::*;

  // The CORDIC processing gain, K = prod_{i=0}^{N-1} sqrt(1 + 2^-2i).
  localparam real K_GAIN = 1.6467602581210656;

  // Comparison tolerance, in LSBs of the output format.  The theoretical
  // bound for N = 14 micro-rotations plus the guard-bit truncation is a
  // little under 5 LSB; 12 leaves margin without hiding a real bug.
  localparam int  TOL_LSB = 12;

  // =======================================================================
  //  1. The transaction
  //
  //  A transaction is a *value*, not a component: it is created, passed
  //  around and thrown away.  In UVM it would extend uvm_sequence_item; the
  //  only thing that adds is automatic copy/compare/print.
  // =======================================================================
  class cordic_txn;

    // ---- stimulus ------------------------------------------------------
    rand data_t  x0;
    rand data_t  y0;
    rand angle_t theta;

    // ---- observed result, filled in by the monitor ----------------------
    data_t x;
    data_t y;

    // ---- bookkeeping ----------------------------------------------------
    int unsigned id;
    static int unsigned next_id = 0;

`ifndef VERILATOR
    // Constrained random.  `inside' with a range is the SystemVerilog way of
    // saying "pick uniformly in this interval"; there is no VHDL equivalent
    // short of writing the generator yourself.
    constraint c_theta {
      theta inside {[-PI_EXT : PI_EXT]};
    }
    // Keep |(x0, y0)| * K comfortably inside the output range so that the
    // saturating output stage is exercised only by the directed tests.
    constraint c_magnitude {
      x0 inside {[-6000 : 6000]};
      y0 inside {[-6000 : 6000]};
    }
    // Bias the distribution towards the interesting angles: the quadrant
    // boundaries, zero, and the extremes.
    constraint c_corners {
      theta dist {
        0                 :/ 1,
        PI_EXT            :/ 1,
        -PI_EXT           :/ 1,
        PI_EXT / 2        :/ 1,
        -PI_EXT / 2       :/ 1,
        [-PI_EXT:PI_EXT]  :/ 20
      };
    }
`endif

    function new();
      id = next_id++;
    endfunction

    // The Verilator build has no constraint solver, so the same class also
    // carries a hand-written fallback.  Chapter 8 explains why this is a
    // reasonable trade-off rather than a defect.
    function void randomize_fallback();
      theta = angle_t'($urandom_range(2 * PI_EXT) - PI_EXT);
      x0    = data_t'($urandom_range(12000) - 6000);
      y0    = data_t'($urandom_range(12000) - 6000);
    endfunction

    function void do_randomize();
`ifdef VERILATOR
      randomize_fallback();
`else
      if (!this.randomize()) $fatal(1, "randomization failed");
`endif
    endfunction

    function string convert2string();
      return $sformatf(
        "txn#%0d  x0=%0d (%.4f)  y0=%0d (%.4f)  theta=%0d (%.4f rad)",
        id, x0, q_to_real(x0, QF), y0, q_to_real(y0, QF),
        theta, q_to_real(theta, QA));
    endfunction

  endclass : cordic_txn


  // =======================================================================
  //  2. The driver
  //
  //  It knows the pin-level protocol and nothing else.  Every access to the
  //  DUT goes through the clocking block, so the driver cannot accidentally
  //  create a race with the DUT's own non-blocking updates.
  // =======================================================================
  class cordic_drv;

    virtual cordic_if vif;
    mailbox #(cordic_txn) req_mbx;      // from the generator
    int unsigned stall_pct = 25;        // random back-pressure on the output

    function new(virtual cordic_if vif, mailbox #(cordic_txn) req_mbx);
      this.vif     = vif;
      this.req_mbx = req_mbx;
    endfunction

    task automatic reset();
      vif.rst_n            <= 1'b0;
      `CB_DRV.req_valid    <= 1'b0;
      `CB_DRV.req_x        <= '0;
      `CB_DRV.req_y        <= '0;
      `CB_DRV.req_theta    <= '0;
      `CB_DRV.rsp_ready    <= 1'b0;
      for (int i = 0; i < 5; i++) `EDGE_DRV;
      vif.rst_n <= 1'b1;
      `EDGE_DRV;
    endtask

    // Drive one request and hold it until the DUT accepts it.
    task automatic send(cordic_txn t);
      `CB_DRV.req_valid <= 1'b1;
      `CB_DRV.req_x     <= t.x0;
      `CB_DRV.req_y     <= t.y0;
      `CB_DRV.req_theta <= t.theta;
      // Wait for the cycle in which valid *and* ready are both high.  The
      // clocking block guarantees that req_ready is the value sampled just
      // before this edge, which is exactly the handshake semantics.
      do `EDGE_DRV; while (`CB_DRV.req_ready !== 1'b1);
      `CB_DRV.req_valid <= 1'b0;
    endtask

    // Two independent threads: one feeds requests, one applies random
    // back-pressure on the response channel.  `fork ... join_none' inside a
    // task is how a class spawns concurrency -- a VHDL process cannot be
    // created at run time at all.
    task automatic run();
      fork
        forever begin
          cordic_txn t;
          req_mbx.get(t);
          send(t);
        end
        forever begin
          if ($urandom_range(99) < stall_pct) begin
            `CB_DRV.rsp_ready <= 1'b0;
            for (int i = $urandom_range(3); i >= 0; i--) `EDGE_DRV;
          end
          `CB_DRV.rsp_ready <= 1'b1;
          `EDGE_DRV;
        end
      join_none
    endtask

  endclass : cordic_drv


  // =======================================================================
  //  3. The monitor
  //
  //  Strictly passive: it never drives a signal.  It reconstructs
  //  transactions from the pins and publishes them.  Keeping the monitor
  //  independent of the driver is what lets the same testbench be reused
  //  against a gate-level netlist, or against the real block inside a
  //  larger system.
  // =======================================================================
  class cordic_mon;

    virtual cordic_if vif;
    mailbox #(cordic_txn) obs_mbx;      // to the scoreboard
    mailbox #(cordic_txn) cov_mbx;      // to the coverage collector

    // Requests that have been accepted but whose result has not come back.
    protected cordic_txn pending[$];

    function new(virtual cordic_if vif,
                 mailbox #(cordic_txn) obs_mbx,
                 mailbox #(cordic_txn) cov_mbx);
      this.vif     = vif;
      this.obs_mbx = obs_mbx;
      this.cov_mbx = cov_mbx;
    endfunction

    task automatic run();
      forever begin
        `EDGE_MON;
        if (vif.rst_n !== 1'b1) continue;

        // Request accepted -> remember what went in.
        if (`CB_MON.req_valid === 1'b1 && `CB_MON.req_ready === 1'b1) begin
          cordic_txn t = new();
          t.x0    = `CB_MON.req_x;
          t.y0    = `CB_MON.req_y;
          t.theta = `CB_MON.req_theta;
          pending.push_back(t);
        end

        // Response accepted -> complete the oldest outstanding request.
        if (`CB_MON.rsp_valid === 1'b1 && `CB_MON.rsp_ready === 1'b1) begin
          cordic_txn t;
          if (pending.size() == 0) begin
            $error("monitor: response with no outstanding request");
          end else begin
            t   = pending.pop_front();
            t.x = `CB_MON.rsp_x;
            t.y = `CB_MON.rsp_y;
            obs_mbx.put(t);
            cov_mbx.put(t);
          end
        end
      end
    endtask

  endclass : cordic_mon


  // =======================================================================
  //  4. The scoreboard and its reference model
  //
  //  The reference model is written at the level of the *specification*
  //  (real-valued trigonometry), not of the implementation.  A model that
  //  re-implements the RTL will happily reproduce the RTL's bugs.
  // =======================================================================
  class cordic_sb;

    mailbox #(cordic_txn) obs_mbx;
    int unsigned n_checked = 0;
    int unsigned n_failed  = 0;
    real         worst_err = 0.0;

    function new(mailbox #(cordic_txn) obs_mbx);
      this.obs_mbx = obs_mbx;
    endfunction

    // The golden model.  Note that it says nothing about micro-rotations,
    // guard bits or quadrant folding: it states what the block is supposed
    // to compute.
    function automatic void predict(input cordic_txn t,
                                    output real x_ref, output real y_ref);
      real th = q_to_real(t.theta, QA);
      real xr = q_to_real(t.x0,    QF);
      real yr = q_to_real(t.y0,    QF);
      x_ref = K_GAIN * (xr * $cos(th) - yr * $sin(th));
      y_ref = K_GAIN * (xr * $sin(th) + yr * $cos(th));
    endfunction

    task automatic run();
      forever begin
        cordic_txn t;
        real x_ref, y_ref, ex, ey;
        obs_mbx.get(t);
        predict(t, x_ref, y_ref);

        ex = (q_to_real(t.x, QF) - x_ref) * (2.0 ** QF);   // error in LSB
        ey = (q_to_real(t.y, QF) - y_ref) * (2.0 ** QF);
        if (ex < 0.0) ex = -ex;
        if (ey < 0.0) ey = -ey;
        if (ex > worst_err) worst_err = ex;
        if (ey > worst_err) worst_err = ey;

        n_checked++;
        if (ex > real'(TOL_LSB) || ey > real'(TOL_LSB)) begin
          n_failed++;
          $error({"MISMATCH %s\n         got  x=%0d y=%0d\n",
                  "         want x=%.1f y=%.1f  (err %.2f / %.2f LSB)"},
                 t.convert2string(), t.x, t.y,
                 x_ref * (2.0 ** QF), y_ref * (2.0 ** QF), ex, ey);
        end
      end
    endtask

    function void report();
      $display("--------------------------------------------------------");
      $display(" scoreboard: %0d transactions checked, %0d failed",
               n_checked, n_failed);
      $display(" worst error: %.2f LSB (tolerance %0d LSB)",
               worst_err, TOL_LSB);
      $display("--------------------------------------------------------");
      if (n_failed == 0 && n_checked > 0) $display(" *** TEST PASSED ***");
      else                                $display(" *** TEST FAILED ***");
    endfunction

  endclass : cordic_sb


  // =======================================================================
  //  5. Functional coverage
  //
  //  Coverage answers "what did I actually exercise?", which is a different
  //  question from "did it work?".  VHDL has no equivalent construct: the
  //  usual workaround is counting in a process and printing a table.
  // =======================================================================
  class cordic_cov;

    mailbox #(cordic_txn) cov_mbx;

`ifndef VERILATOR
    angle_t sampled_theta;
    data_t  sampled_x0;

    covergroup cg_stimulus;
      option.per_instance = 1;

      cp_quadrant : coverpoint sampled_theta {
        bins q3_neg = {[-PI_EXT     : -PI_EXT/2 - 1]};
        bins q4_neg = {[-PI_EXT/2   : -1]};
        bins zero   = {0};
        bins q1_pos = {[1           :  PI_EXT/2 - 1]};
        bins q2_pos = {[PI_EXT/2    :  PI_EXT]};
      }
      cp_sign_x : coverpoint sampled_x0 {
        bins neg  = {[-32768 : -1]};
        bins zero = {0};
        bins pos  = {[1 : 32767]};
      }
      x_quadrant_sign : cross cp_quadrant, cp_sign_x;
    endgroup
`endif

    function new(mailbox #(cordic_txn) cov_mbx);
      this.cov_mbx = cov_mbx;
`ifndef VERILATOR
      cg_stimulus  = new();
`endif
    endfunction

    task automatic run();
      forever begin
        cordic_txn t;
        cov_mbx.get(t);
`ifndef VERILATOR
        sampled_theta = t.theta;
        sampled_x0    = t.x0;
        cg_stimulus.sample();
`endif
      end
    endtask

    function void report();
`ifndef VERILATOR
      $display(" functional coverage: %.1f %%", cg_stimulus.get_coverage());
`else
      $display(" functional coverage: not collected (Verilator build)");
`endif
    endfunction

  endclass : cordic_cov


  // =======================================================================
  //  6. The environment
  //
  //  Construction, connection and start-up, in that order.  UVM calls these
  //  build_phase, connect_phase and run_phase and calls them for you; here
  //  you call them yourself, which is one fewer thing to learn while the
  //  structure is still new.
  // =======================================================================
  class cordic_env;

    virtual cordic_if vif;

    mailbox #(cordic_txn) req_mbx;
    mailbox #(cordic_txn) obs_mbx;
    mailbox #(cordic_txn) cov_mbx;

    cordic_drv drv;
    cordic_mon mon;
    cordic_sb  sb;
    cordic_cov cov;

    function new(virtual cordic_if vif);
      this.vif = vif;
      // "build"
      req_mbx = new();
      obs_mbx = new();
      cov_mbx = new();
      drv     = new(vif, req_mbx);
      mon     = new(vif, obs_mbx, cov_mbx);
      sb      = new(obs_mbx);
      cov     = new(cov_mbx);
    endfunction

    task automatic run();
      fork
        mon.run();
        sb.run();
        cov.run();
      join_none
      drv.run();
    endtask

    // Stimulus generation lives in the test, not in the environment: the
    // environment is reusable, the stimulus is not.
    task automatic send_random(int unsigned n);
      repeat (n) begin
        cordic_txn t = new();
        t.do_randomize();
        req_mbx.put(t);
      end
    endtask

    task automatic send_directed(data_t x0, data_t y0, angle_t theta);
      cordic_txn t = new();
      t.x0 = x0; t.y0 = y0; t.theta = theta;
      req_mbx.put(t);
    endtask

    // Wait until every transaction that was sent has been checked.
    task automatic wait_drain(int unsigned expected, int unsigned timeout_cyc);
      int unsigned waited = 0;
      while (sb.n_checked < expected && waited < timeout_cyc) begin
        `EDGE_MON;
        waited++;
      end
      if (sb.n_checked < expected)
        $fatal(1, "timeout: only %0d of %0d transactions completed",
               sb.n_checked, expected);
    endtask

    function void report();
      sb.report();
      cov.report();
    endfunction

  endclass : cordic_env

endpackage : tb_cordic_pkg
