// ===========================================================================
//  tb_vectors.cpp -- a bit-exact C++ testbench driven by generated vectors.
//
//  The other testbenches compare against a floating point model with a
//  tolerance, which checks that the block computes a rotation.  This one
//  compares against the Python model bit for bit, which checks that the RTL
//  and the model implement the *same* fixed-point algorithm.  Both checks are
//  worth having, and they fail in different ways:
//
//    * a tolerance check fails when the maths is wrong;
//    * a bit-exact check fails when a rounding mode, a guard bit or a
//      truncation has drifted between the model and the RTL.
//
//  The vectors arrive as a generated header, so a stale table is a compile
//  error rather than a mysterious mismatch:
//
//      make vectors && make bitexact
// ===========================================================================
#include "Vcordic_rot.h"
#include "cordic_vectors.h"
#include "verilated.h"

#include <cstdio>
#include <cstdlib>

// ---------------------------------------------------------------------------
//  A thin wrapper around the Verilated model.
//
//  Note the shape of the clock: set the inputs while the clock is low, call
//  eval() so that the combinational cone settles, and only then raise the
//  clock.  This is the C++ spelling of "sample in the Preponed region".
// ---------------------------------------------------------------------------
class Bench {
 public:
  explicit Bench(VerilatedContext* ctx) : ctx_(ctx), dut_(new Vcordic_rot) {}
  ~Bench() { dut_->final(); delete dut_; }

  Vcordic_rot* dut() { return dut_; }
  uint64_t cycles() const { return cycles_; }

  void reset(int n = 5) {
    dut_->clk_i = 0;
    dut_->rst_ni = 0;
    dut_->req_valid_i = 0;
    dut_->rsp_ready_i = 1;
    dut_->req_x_i = dut_->req_y_i = dut_->req_theta_i = 0;
    for (int i = 0; i < n; ++i) tick();
    dut_->rst_ni = 1;
    tick();
  }

  // One clock cycle.  Inputs must already be set when this is called.
  void tick() {
    dut_->clk_i = 0;
    dut_->eval();
    ctx_->timeInc(5000);   // 5 ns at 1 ps precision
    dut_->clk_i = 1;
    dut_->eval();
    ctx_->timeInc(5000);
    ++cycles_;
  }

 private:
  VerilatedContext* ctx_;
  Vcordic_rot* dut_;
  uint64_t cycles_ = 0;
};

// ---------------------------------------------------------------------------
//  Verilator gives a 16-bit port the C type uint16_t (SData).  It knows
//  nothing about signedness, so the sign extension is yours to do.  Getting
//  this wrong is the single most common bug in a C++ testbench, and it hides
//  well: every positive result is correct.
// ---------------------------------------------------------------------------
static inline int16_t as_signed(uint16_t raw) {
  return static_cast<int16_t>(raw);
}

int main(int argc, char** argv) {
  VerilatedContext ctx;
  ctx.commandArgs(argc, argv);

  Bench b(&ctx);
  Vcordic_rot* d = b.dut();
  b.reset();

  unsigned failures = 0;
  unsigned checked = 0;

  for (unsigned i = 0; i < kCordicVecCount; ++i) {
    const CordicVec& v = kCordicVectors[i];

    // ---- drive the request, holding it until req_ready_o is seen --------
    d->req_x_i = static_cast<uint16_t>(v.x0);
    d->req_y_i = static_cast<uint16_t>(v.y0);
    d->req_theta_i = static_cast<uint16_t>(v.theta);
    d->req_valid_i = 1;
    unsigned guard = 0;
    do {
      d->clk_i = 0;
      d->eval();                       // settle, then look at req_ready_o
      if (d->req_ready_o) break;
      b.tick();
    } while (++guard < 1000);
    b.tick();                          // the cycle in which it is accepted
    d->req_valid_i = 0;

    // ---- wait for the response ------------------------------------------
    guard = 0;
    while (guard++ < 1000) {
      d->clk_i = 0;
      d->eval();
      if (d->rsp_valid_o) break;
      b.tick();
    }
    if (guard >= 1000) {
      std::fprintf(stderr, "vector %u: no response\n", i);
      ++failures;
      break;
    }

    const int16_t got_x = as_signed(d->rsp_x_o);
    const int16_t got_y = as_signed(d->rsp_y_o);
    b.tick();                          // consume it (rsp_ready_i is tied high)

    ++checked;
    if (got_x != v.x || got_y != v.y) {
      if (failures < 10) {
        std::printf("MISMATCH vector %u:  x0=%d y0=%d theta=%d\n"
                    "          got  x=%d y=%d\n"
                    "          want x=%d y=%d\n",
                    i, v.x0, v.y0, v.theta, got_x, got_y, v.x, v.y);
      }
      ++failures;
    }
  }

  std::printf("----------------------------------------------\n");
  std::printf(" bit-exact check against the Python model\n");
  std::printf(" vectors generated with seed %u\n", kCordicVecSeed);
  std::printf(" %u checked, %u mismatches, %llu clock cycles\n",
              checked, failures,
              static_cast<unsigned long long>(b.cycles()));
  std::printf(" %s\n", failures ? "*** TEST FAILED ***" : "*** TEST PASSED ***");
  std::printf("----------------------------------------------\n");
  return failures ? 1 : 0;
}
