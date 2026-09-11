// ===========================================================================
//  main_uvmlike.cpp -- the "test" layer and the clock loop.
// ===========================================================================
#include "cordic_env.h"
#include "verilated.h"

#include <cstring>

// ---------------------------------------------------------------------------
//  The test: configures, builds, runs, reports.  This is the only place that
//  knows both the environment and the clock.
// ---------------------------------------------------------------------------
class CordicTest : public Component {
  public:
    SVTLM_REGISTER(CordicTest);
    CordicTest(const std::string& n, Component* p) : Component(n, p) {}

    CordicVif  vif;
    CordicEnv* env = nullptr;

    void build() override {
        env = Factory::get().createAs<CordicEnv>("CordicEnv", "env", this);
        env->vif = &vif;
    }

    // The clock loop.  Everything above is called from here, once per cycle.
    void run(VerilatedContext& ctx, unsigned max_cycles) {
        Vcordic_rot* d = vif.dut;
        d->clk_i = 0; d->rst_ni = 0;
        d->req_valid_i = 0; d->rsp_ready_i = 0;
        d->req_x_i = d->req_y_i = d->req_theta_i = 0;

        for (unsigned c = 0; c < max_cycles; ++c) {
            d->clk_i = 0;
            d->eval();                 // settle: pre-edge values are now valid
            if (c == 5) d->rst_ni = 1;
            if (c > 5) tickAll();      // every component sees this cycle
            ctx.timeInc(5000);         // 5 ns, in 1 ps precision units
            d->clk_i = 1;
            d->eval();                 // the rising edge
            ctx.timeInc(5000);
            vif.cycle = c;
            if (finished()) break;
        }
    }
    bool finished() const {
        return env->agt->seq->done() && env->agt->drv->q.empty() &&
               env->sb->checked >= env->agt->seq->n_total;
    }
    int status() const { return env->sb->failed ? 1 : 0; }
};

int main(int argc, char** argv) {
    VerilatedContext ctx;
    ctx.commandArgs(argc, argv);

    // ---- configuration, before build() ---------------------------------
    ConfigDb& cfg = ConfigDb::get();
    int n = 200;
    for (int i = 1; i < argc; ++i) {
        if (!strncmp(argv[i], "+n=", 3)) n = atoi(argv[i] + 3);
        if (!strncmp(argv[i], "+stall=", 7))
            cfg.setInt("*", "stall_pct", atoi(argv[i] + 7));
        if (!strcmp(argv[i], "+strict"))
            Factory::get().setTypeOverride("CordicSb", "CordicSbStrict");
    }
    cfg.setInt("*", "n_txn", n);
    cfg.setInt("test.env.sb", "tol_lsb", 12);

    // ---- elaborate ------------------------------------------------------
    Vcordic_rot dut{&ctx};
    CordicTest  test("test", nullptr);
    test.vif.dut = &dut;

    test.buildAll();
    test.connectAll();
    printf("--- component tree ---\n");
    test.printTree();
    printf("--- run ---\n");

    test.run(ctx, 200u * unsigned(n) + 1000u);

    dut.final();
    printf("--- report ---\n");
    test.reportAll();
    printf("*** TEST %s ***\n", test.status() ? "FAILED" : "PASSED");
    return test.status();
}
