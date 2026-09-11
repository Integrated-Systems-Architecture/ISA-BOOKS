// ===========================================================================
//  cordic_pkg.sv -- shared declarations for the CORDIC rotator.
//
//  This package is the SystemVerilog counterpart of cordic_pkg.vhd.  It is
//  worth reading the two side by side: they contain exactly the same
//  information, but SystemVerilog lets the design *and* the testbench import
//  it with a single `import cordic_pkg::*;`, while VHDL needs the design unit
//  to name the library and the package separately.
//
//  Number formats
//  --------------
//    x, y     signed, DW bits, QF fractional bits   (Q1.14 -> [-2, 2) )
//    theta    signed, AW bits, QA fractional bits   (Q2.13 -> [-4, 4) )
//
//  Internally the datapath is widened by GL bits at the bottom (precision)
//  and GM bits at the top (headroom for the CORDIC processing gain).
// ===========================================================================
// verilator lint_off UNUSEDPARAM
// (several constants below are consumed only by testbenches)
package cordic_pkg;

  timeunit      1ns;
  timeprecision 1ps;

  // -----------------------------------------------------------------------
  // Format parameters.  `parameter' at package scope behaves like VHDL's
  // deferred constant: it can be overridden only by a tool switch, not by
  // an instance, so treat it as a constant.
  // -----------------------------------------------------------------------
  parameter int unsigned DW = 16;   // external x/y width
  parameter int unsigned QF = 14;   // external x/y fractional bits
  parameter int unsigned AW = 16;   // external angle width
  parameter int unsigned QA = 13;   // external angle fractional bits
  parameter int unsigned N  = 14;   // number of micro-rotations
  parameter int unsigned GL = 2;    // guard bits at the LSB side
  parameter int unsigned GM = 2;    // guard bits at the MSB side

  localparam int unsigned IW  = DW + GL + GM;   // internal x/y width      (20)
  localparam int unsigned IQF = QF + GL;        // internal x/y frac. bits (16)
  localparam int unsigned IA  = AW + GL;        // internal angle width    (18)
  localparam int unsigned IQA = QA + GL;        // internal angle frac.    (15)

  // -----------------------------------------------------------------------
  // Types.  A `typedef' here plays the role of a VHDL subtype declared in a
  // package -- but note that SystemVerilog types carry no range checking:
  // `data_t' is simply "20 bits, interpreted as two's complement".
  // -----------------------------------------------------------------------
  typedef logic signed [DW-1:0] data_t;    // external x/y
  typedef logic signed [AW-1:0] angle_t;   // external angle
  typedef logic signed [IW-1:0] idata_t;   // internal x/y
  typedef logic signed [IA-1:0] iangle_t;  // internal angle

  // A packed struct is a *bit vector with named fields*.  It can cross a
  // module port, be assigned as a whole, and be cast to and from a plain
  // vector -- VHDL records cannot be treated as vectors at all.
  typedef struct packed {
    data_t  x;
    data_t  y;
    angle_t theta;
  } cordic_req_t;

  typedef struct packed {
    data_t x;
    data_t y;
  } cordic_rsp_t;

  // -----------------------------------------------------------------------
  // Elaboration-time constants.
  //
  // `$atan' and friends are real-valued system functions.  Calling them in a
  // constant expression is the SystemVerilog equivalent of using
  // ieee.math_real in a VHDL constant: the value is computed once, by the
  // tool, and never appears in the netlist.
  // -----------------------------------------------------------------------
  localparam int signed MAX_DATA =  (1 << (DW - 1)) - 1;   //  32767
  localparam int signed MIN_DATA = -(1 << (DW - 1));       // -32768

  // pi/2 and pi in the internal angle format
  localparam int signed HALF_PI_INT = 51472;   // round(pi/2 * 2**IQA)
  localparam int signed PI_INT      = 102944;  // round(pi   * 2**IQA)
  // pi in the *external* angle format, used by the input range check
  localparam int signed PI_EXT      = 25736;   // round(pi   * 2**QA)

  // The processing gain K = prod sqrt(1 + 2**-2i) and its reciprocal, in the
  // external x/y format.  Seed the rotator with X0_UNIT to obtain
  // (cos theta, sin theta) directly on the output.
  localparam int signed X0_UNIT = 9949;        // round(2**QF / 1.646760)

  // -----------------------------------------------------------------------
  // The arctangent ROM.
  //
  // A function that returns an unpacked array, used to initialise a
  // `localparam': this is how you build a compile-time table in
  // SystemVerilog.  The whole thing disappears into constants during
  // elaboration, exactly like a VHDL constant array initialised by a
  // function.
  // -----------------------------------------------------------------------
  typedef iangle_t atan_rom_t [N];

  function automatic atan_rom_t build_atan_rom();
    atan_rom_t rom;
    for (int i = 0; i < int'(N); i++) begin
      // $atan works on `real'; $rtoi truncates, so add 0.5 to round.
      rom[i] = iangle_t'($rtoi($atan(2.0 ** (-i)) * (2.0 ** IQA) + 0.5));
    end
    return rom;
  endfunction

  localparam atan_rom_t ATAN_ROM = build_atan_rom();

  // -----------------------------------------------------------------------
  // Narrow the internal datapath back to the external format, with
  // saturation.  Truncation of the GL guard bits is an arithmetic shift
  // right, which rounds towards minus infinity -- the golden model in
  // Python does exactly the same, so the two agree bit for bit.
  // -----------------------------------------------------------------------
  // The GL guard bits of `v' are dropped on purpose.
  // verilator lint_off UNUSEDSIGNAL
  function automatic data_t sat_narrow(input idata_t v);
    logic signed [IW-GL-1:0] t;   // DW + GM bits
    // The low IW-GL bits of an arithmetic shift right by GL are exactly the
    // part-select v[IW-1:GL]; writing it this way keeps the widths explicit.
    t = v[IW-1:GL];
    if      (int'(t) > MAX_DATA) sat_narrow = data_t'(MAX_DATA);
    else if (int'(t) < MIN_DATA) sat_narrow = data_t'(MIN_DATA);
    else                         sat_narrow = data_t'(t);
  endfunction
  // verilator lint_on UNUSEDSIGNAL

  // Convenience for testbenches: fixed point <-> real.
  function automatic real q_to_real(input int signed v, input int unsigned f);
    return real'(v) / (2.0 ** f);
  endfunction

  function automatic int signed real_to_q(input real v, input int unsigned f);
    return $rtoi(v * (2.0 ** f) + (v >= 0.0 ? 0.5 : -0.5));
  endfunction

endpackage : cordic_pkg
// verilator lint_on UNUSEDPARAM
