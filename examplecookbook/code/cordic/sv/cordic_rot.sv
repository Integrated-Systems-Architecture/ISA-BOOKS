// ===========================================================================
//  cordic_rot.sv -- iterative (folded) CORDIC rotator, rotation mode.
//
//  Rotates the vector (x, y) by theta and returns
//
//      x' = K * ( x*cos(theta) - y*sin(theta) )
//      y' = K * ( x*sin(theta) + y*cos(theta) )
//
//  where K ~ 1.6468 is the CORDIC processing gain.  Seed the core with
//  x = cordic_pkg::X0_UNIT, y = 0 to obtain (cos theta, sin theta) directly.
//
//  One micro-rotation is performed per clock cycle, so a transaction takes
//  N + 2 cycles.  Request and response use an independent valid/ready
//  handshake.
//
//  Accepted input range: |theta| <= pi.  A larger angle is flagged by an
//  immediate assertion; the coarse-rotation stage only removes one quadrant.
// ===========================================================================
`timescale 1ns/1ps

module cordic_rot
  import cordic_pkg::*;
#(
  // The number of micro-rotations is a module parameter so that the same
  // source can be elaborated at several precisions -- the equivalent of a
  // VHDL generic.  It defaults to the package value.
  parameter int unsigned ITER = N
) (
  input  logic   clk_i,
  input  logic   rst_ni,      // asynchronous, active low

  // ---- request channel -------------------------------------------------
  input  logic   req_valid_i,
  output logic   req_ready_o,
  input  data_t  req_x_i,
  input  data_t  req_y_i,
  input  angle_t req_theta_i,

  // ---- response channel ------------------------------------------------
  output logic   rsp_valid_o,
  input  logic   rsp_ready_i,
  output data_t  rsp_x_o,
  output data_t  rsp_y_o
);

  localparam int unsigned CNT_W = (ITER > 1) ? $clog2(ITER) : 1;

  // -----------------------------------------------------------------------
  // An enumerated type for the state.  Unlike a VHDL enumeration, a
  // SystemVerilog enum has an explicit base type -- here two bits -- which is
  // what actually goes into the flip-flops.  Simulators and waveform viewers
  // still show the symbolic name.
  // -----------------------------------------------------------------------
  typedef enum logic [1:0] {
    ST_IDLE   = 2'b00,
    ST_ROTATE = 2'b01,
    ST_DONE   = 2'b10
  } state_e;

  state_e  state_q, state_d;

  idata_t              x_q, x_d;
  idata_t              y_q, y_d;
  iangle_t             z_q, z_d;
  logic [CNT_W-1:0]    iter_q, iter_d;

  // -----------------------------------------------------------------------
  // Stage 1: widen and coarse-rotate.
  //
  // The micro-rotation series converges only for |z| <= 1.7433 rad, so an
  // angle outside +-pi/2 is first rotated by a whole quadrant:
  //     +pi/2 : (x, y) -> (-y,  x)
  //     -pi/2 : (x, y) -> ( y, -x)
  // Both are exact -- no arithmetic error is introduced.
  // -----------------------------------------------------------------------
  idata_t  x_ext, y_ext, x_load, y_load;
  iangle_t z_ext, z_load;

  always_comb begin
    // A cast to a wider *signed* type sign-extends.  This is the one place
    // where SystemVerilog's implicit width rules genuinely help: the cast
    // says what we mean and the shift then adds the guard bits.
    x_ext = idata_t'(req_x_i)      <<< GL;
    y_ext = idata_t'(req_y_i)      <<< GL;
    z_ext = iangle_t'(req_theta_i) <<< GL;

    if (z_ext > iangle_t'(HALF_PI_INT)) begin
      x_load = -y_ext;
      y_load =  x_ext;
      z_load =  z_ext - iangle_t'(HALF_PI_INT);
    end else if (z_ext < -iangle_t'(HALF_PI_INT)) begin
      x_load =  y_ext;
      y_load = -x_ext;
      z_load =  z_ext + iangle_t'(HALF_PI_INT);
    end else begin
      x_load =  x_ext;
      y_load =  y_ext;
      z_load =  z_ext;
    end
  end

  // -----------------------------------------------------------------------
  // Stage 2: one micro-rotation, purely combinational.
  //
  //     d      = sign(z)
  //     x[i+1] = x[i] - d * (y[i] >>> i)
  //     y[i+1] = y[i] + d * (x[i] >>> i)
  //     z[i+1] = z[i] - d * atan(2**-i)
  //
  // Note that `>>>' on a signed operand is an arithmetic shift.  Getting
  // this wrong is the single most common bug when porting fixed point code
  // from VHDL, where shift_right on a `signed' is arithmetic by definition.
  // -----------------------------------------------------------------------
  idata_t  x_sh, y_sh, x_rot, y_rot;
  iangle_t z_rot, atan_i;
  logic    ccw;                       // 1 = rotate counter-clockwise

  always_comb begin
    ccw    = ~z_q[IA-1];              // z >= 0
    x_sh   = x_q >>> iter_q;
    y_sh   = y_q >>> iter_q;
    atan_i = ATAN_ROM[iter_q];

    if (ccw) begin
      x_rot = x_q - y_sh;
      y_rot = y_q + x_sh;
      z_rot = z_q - atan_i;
    end else begin
      x_rot = x_q + y_sh;
      y_rot = y_q - x_sh;
      z_rot = z_q + atan_i;
    end
  end

  // -----------------------------------------------------------------------
  // Stage 3: the control FSM.
  //
  // `always_comb' guarantees a complete sensitivity list, and the default
  // assignments at the top of the block guarantee that every signal is
  // written on every path -- which is how you avoid an inferred latch.
  // `unique case' asks the simulator to check at run time that exactly one
  // branch matches; there is no VHDL equivalent short of writing the
  // assertion yourself.
  // -----------------------------------------------------------------------
  always_comb begin
    state_d     = state_q;
    x_d         = x_q;
    y_d         = y_q;
    z_d         = z_q;
    iter_d      = iter_q;
    req_ready_o = 1'b0;
    rsp_valid_o = 1'b0;

    unique case (state_q)
      ST_IDLE: begin
        req_ready_o = 1'b1;
        if (req_valid_i) begin
          x_d     = x_load;
          y_d     = y_load;
          z_d     = z_load;
          iter_d  = '0;
          state_d = ST_ROTATE;
        end
      end

      ST_ROTATE: begin
        x_d = x_rot;
        y_d = y_rot;
        z_d = z_rot;
        if (iter_q == CNT_W'(ITER - 1)) begin
          state_d = ST_DONE;
        end else begin
          iter_d = iter_q + CNT_W'(1);
        end
      end

      ST_DONE: begin
        rsp_valid_o = 1'b1;
        if (rsp_ready_i) state_d = ST_IDLE;
      end

      default: state_d = ST_IDLE;
    endcase
  end

  // -----------------------------------------------------------------------
  // Stage 4: the state registers.
  //
  // One `always_ff' per clock domain, non-blocking assignments only.  The
  // asynchronous reset appears in the sensitivity list exactly as it does in
  // a VHDL process.
  // -----------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= ST_IDLE;
      x_q     <= '0;
      y_q     <= '0;
      z_q     <= '0;
      iter_q  <= '0;
    end else begin
      state_q <= state_d;
      x_q     <= x_d;
      y_q     <= y_d;
      z_q     <= z_d;
      iter_q  <= iter_d;
    end
  end

  // -----------------------------------------------------------------------
  // Outputs.  Saturating narrow-down lives in the package so that the
  // testbench can call exactly the same function.
  // -----------------------------------------------------------------------
  assign rsp_x_o = sat_narrow(x_q);
  assign rsp_y_o = sat_narrow(y_q);

  // -----------------------------------------------------------------------
  // Built-in checks.  These are part of the *design*, not of a testbench:
  // they travel with the module and fire in every simulation that
  // instantiates it.  Synthesis tools ignore them.
  // -----------------------------------------------------------------------
`ifndef SYNTHESIS
  // Immediate assertion: the accepted input range.
  always_ff @(posedge clk_i) begin
    if (rst_ni && req_valid_i && req_ready_o) begin
      assert (req_theta_i <=  angle_t'(PI_EXT) &&
              req_theta_i >= -angle_t'(PI_EXT))
        else $error("cordic_rot: |theta| > pi (theta = %0d)",
                    $signed(req_theta_i));
    end
  end

  // Concurrent assertion: a request must stay stable while it is stalled.
  property p_req_stable;
    @(posedge clk_i) disable iff (!rst_ni)
      (req_valid_i && !req_ready_o) |=>
        $stable(req_x_i) && $stable(req_y_i) && $stable(req_theta_i);
  endproperty
  a_req_stable : assert property (p_req_stable)
    else $error("cordic_rot: request payload changed while stalled");
`endif

endmodule : cordic_rot
