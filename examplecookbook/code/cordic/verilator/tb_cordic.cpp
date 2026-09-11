// tb_cordic.cpp -- a self-checking C++ testbench for cordic_rot.
#include "Vcordic_rot.h"
#include "verilated.h"
#if VM_TRACE_FST
# include "verilated_fst_c.h"
using TraceC = VerilatedFstC;
static const char* TRACE_FILE = "cordic.fst";
#else
# include "verilated_vcd_c.h"
using TraceC = VerilatedVcdC;
static const char* TRACE_FILE = "cordic.vcd";
#endif

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <random>
#include <cstring>
#include <cstdlib>

static const double K_GAIN = 1.6467602581210656;
static const int    QF = 14, QA = 13;
static const int    PI_EXT = 25736;      // round(pi * 2^QA)
static const double TOL_LSB = 12.0;

struct Txn {
    int16_t x0, y0, theta;   // stimulus
    int16_t x, y;            // observed
};

class CordicTb {
  public:
    VerilatedContext ctx;
    Vcordic_rot*     dut;
    TraceC*          tfp = nullptr;
    uint64_t         cycles = 0;
    unsigned         checked = 0, failed = 0;
    double           worst = 0.0;

    CordicTb(int argc, char** argv) {
        ctx.commandArgs(argc, argv);
        dut = new Vcordic_rot{&ctx};
        dut->clk_i = 0; dut->rst_ni = 0;
        dut->req_valid_i = 0; dut->rsp_ready_i = 0;
        dut->req_x_i = 0; dut->req_y_i = 0; dut->req_theta_i = 0;
    }
    ~CordicTb() { closeTrace(); delete dut; }

    void openTrace(const char* name) {
        ctx.traceEverOn(true);
        tfp = new TraceC;
        dut->trace(tfp, 99);
        tfp->open(name);
    }
    void closeTrace() { if (tfp) { tfp->close(); delete tfp; tfp = nullptr; } }

    // One clock period.  Inputs written before the call are seen by the
    // rising edge; outputs read after the call are the post-edge values.
    void tick() {
        dut->clk_i = 0; dut->eval();
        if (tfp) tfp->dump(ctx.time());
        ctx.timeInc(5);

        dut->clk_i = 1; dut->eval();
        if (tfp) tfp->dump(ctx.time());
        ctx.timeInc(5);
        ++cycles;
    }
    // The combinational outputs of the current cycle, before the edge.
    void settle() { dut->clk_i = 0; dut->eval(); }

    void reset(int n = 5) {
        dut->rst_ni = 0;
        for (int i = 0; i < n; ++i) tick();
        dut->rst_ni = 1;
        tick();
    }

    void check(const Txn& t) {
        double th = double(t.theta) / (1 << QA);
        double xr = double(t.x0)    / (1 << QF);
        double yr = double(t.y0)    / (1 << QF);
        double rx = K_GAIN * (xr * std::cos(th) - yr * std::sin(th));
        double ry = K_GAIN * (xr * std::sin(th) + yr * std::cos(th));
        double ex = std::fabs(double(t.x) - rx * (1 << QF));
        double ey = std::fabs(double(t.y) - ry * (1 << QF));
        if (ex > worst) worst = ex;
        if (ey > worst) worst = ey;
        ++checked;
        if (ex > TOL_LSB || ey > TOL_LSB) {
            ++failed;
            printf("MISMATCH x0=%d y0=%d th=%d : got (%d,%d) "
                   "want (%.1f,%.1f) err %.2f/%.2f LSB\n",
                   t.x0, t.y0, t.theta, t.x, t.y,
                   rx * (1 << QF), ry * (1 << QF), ex, ey);
        }
    }
};

int main(int argc, char** argv) {
    CordicTb tb(argc, argv);

    int  n = 200;
    bool trace = false, bp = false;
    for (int i = 1; i < argc; ++i) {
        if (!strncmp(argv[i], "+n=", 3))   n = atoi(argv[i] + 3);
        if (!strcmp (argv[i], "+trace"))   trace = true;
        if (!strcmp (argv[i], "+bp"))      bp = true;
    }
    if (trace) tb.openTrace(TRACE_FILE);

    tb.reset();
    tb.dut->rsp_ready_i = 1;

    std::mt19937 rng(1);
    std::uniform_int_distribution<int> dth(-PI_EXT, PI_EXT);
    std::uniform_int_distribution<int> dxy(-6000, 6000);

    for (int i = 0; i < n; ++i) {
        Txn t;
        t.theta = int16_t(dth(rng));
        t.x0    = int16_t(dxy(rng));
        t.y0    = int16_t(dxy(rng));

        // --- drive the request and hold it until it is accepted ---------
        tb.dut->req_valid_i = 1;
        tb.dut->req_x_i     = uint16_t(t.x0);
        tb.dut->req_y_i     = uint16_t(t.y0);
        tb.dut->req_theta_i = uint16_t(t.theta);
        bool accepted;
        do {
            tb.settle();
            accepted = tb.dut->req_ready_o;
            tb.tick();
        } while (!accepted);
        tb.dut->req_valid_i = 0;

        // --- wait for the response, with optional back-pressure ---------
        int  guard = 0;
        bool done  = false;
        while (!done && guard++ < 1000) {
            if (bp) tb.dut->rsp_ready_i = (rng() % 4) != 0;
            tb.settle();
            if (tb.dut->rsp_valid_o && tb.dut->rsp_ready_i) {
                t.x  = int16_t(tb.dut->rsp_x_o);
                t.y  = int16_t(tb.dut->rsp_y_o);
                done = true;
            }
            tb.tick();
        }
        if (!done) { printf("TIMEOUT\n"); return 2; }
        tb.check(t);
    }

    tb.dut->final();
    tb.closeTrace();
#if VM_COVERAGE
    Verilated::mkdir("logs");
    tb.ctx.coveragep()->write("logs/coverage.dat");
#endif
    printf("----------------------------------------------\n");
    printf(" %u transactions, %u failures, worst error %.2f LSB\n",
           tb.checked, tb.failed, tb.worst);
    printf(" %llu clock cycles simulated\n", (unsigned long long)tb.cycles);
    printf(" *** TEST %s ***\n", tb.failed ? "FAILED" : "PASSED");
    return tb.failed ? 1 : 0;
}
