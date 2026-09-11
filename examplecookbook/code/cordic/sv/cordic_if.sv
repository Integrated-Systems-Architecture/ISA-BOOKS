// ===========================================================================
//  cordic_if.sv -- the testbench view of the CORDIC pins.
//
//  An interface is the single construct that VHDL has no answer to.  It
//  bundles the wires, the *timing* with which the testbench uses them
//  (clocking blocks) and the direction each participant sees (modports).
//
//  In VHDL the same job needs: a record type in a package, a second record
//  for the opposite direction, hand-written delays in every driver, and a
//  block of port map lines in every instantiation.
// ===========================================================================
`timescale 1ns/1ps

interface cordic_if (input logic clk);

  import cordic_pkg::*;

  logic   rst_n;

  logic   req_valid;
  logic   req_ready;
  data_t  req_x;
  data_t  req_y;
  angle_t req_theta;

  logic   rsp_valid;
  logic   rsp_ready;
  data_t  rsp_x;
  data_t  rsp_y;

  // -----------------------------------------------------------------------
  // Clocking block for the driver.
  //
  // `default input #1step' samples in the *Preponed* region, i.e. the value
  // that existed just before the clock edge -- no race with the DUT's own
  // non-blocking updates.  `output #1ns' drives 1 ns after the edge, which
  // is what a real ATE or a real board would do.
  //
  // This is the construct that removes the whole class of "my testbench
  // reads the new value instead of the old one" bugs that VHDL solves by
  // convention (drive on the falling edge) rather than by language.
  // -----------------------------------------------------------------------
  // Note: version 5.020 of Verilator silently DROPS a non-blocking assignment
  // made through a virtual interface to a signal that is a clocking-block
  // output: the write simply never happens, with no warning.  The clocking
  // blocks are therefore compiled out of that build; see Chapter 8.
`ifndef VERILATOR
  clocking drv_cb @(posedge clk);
    default input #1step output #1ns;
    output req_valid, req_x, req_y, req_theta;
    output rsp_ready;
    input  req_ready, rsp_valid, rsp_x, rsp_y;
  endclocking

  // Passive: everything is an input.
  clocking mon_cb @(posedge clk);
    default input #1step;
    input req_valid, req_ready, req_x, req_y, req_theta;
    input rsp_valid, rsp_ready, rsp_x, rsp_y;
  endclocking
`endif

  // -----------------------------------------------------------------------
  // Modports name the roles.  `drv' and `mon' hand out a clocking block, so
  // a class that uses them physically cannot drive a signal at the wrong
  // time.
  // -----------------------------------------------------------------------
  modport dut (
    input  clk, rst_n,
    input  req_valid, req_x, req_y, req_theta,
    output req_ready,
    output rsp_valid, rsp_x, rsp_y,
    input  rsp_ready
  );

  // A modport that hands out a clocking block is legal IEEE 1800 but is not
  // yet supported by Verilator 5.020, so it is guarded.  The testbench
  // classes reach the clocking blocks directly through the virtual
  // interface, which works everywhere.
`ifndef VERILATOR
  modport drv (clocking drv_cb, output rst_n, input clk);
  modport mon (clocking mon_cb, input rst_n, input clk);
`endif

endinterface : cordic_if
