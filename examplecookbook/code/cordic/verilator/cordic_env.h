// ===========================================================================
//  cordic_env.h -- a UVM-shaped environment for cordic_rot, built on svtlm.h.
// ===========================================================================
#ifndef CORDIC_ENV_H_
#define CORDIC_ENV_H_

#include "Vcordic_rot.h"
#include "svtlm.h"

#include <cmath>
#include <cstdint>
#include <deque>
#include <random>

using svtlm::AnalysisPort;
using svtlm::Component;
using svtlm::ConfigDb;
using svtlm::Factory;

static const double K_GAIN = 1.6467602581210656;
static const int    QF = 14, QA = 13, PI_EXT = 25736;

// ---------------------------------------------------------------------------
//  1. The transaction.  A plain value type: no base class, no factory.
// ---------------------------------------------------------------------------
struct CordicTxn {
    int16_t x0 = 0, y0 = 0, theta = 0;   // stimulus
    int16_t x = 0, y = 0;                // observed response
    unsigned id = 0;
};

// ---------------------------------------------------------------------------
//  2. The pin-level view.  The C++ answer to a virtual interface: one struct
//     that every component holds a pointer to.
// ---------------------------------------------------------------------------
struct CordicVif {
    Vcordic_rot* dut = nullptr;
    uint64_t     cycle = 0;
};

// ---------------------------------------------------------------------------
//  3. Sequence: produces transactions into the driver's queue.
// ---------------------------------------------------------------------------
class CordicSeq : public Component {
  public:
    SVTLM_REGISTER(CordicSeq);
    CordicSeq(const std::string& n, Component* p) : Component(n, p) {}

    std::deque<CordicTxn>* q = nullptr;   // wired by the agent
    unsigned n_total = 0, n_sent = 0;

    void build() override {
        n_total = cfgInt("n_txn", 200);
        rng_.seed(cfgInt("seed", 1));
        info("will generate %u transactions", n_total);
    }
    void tick() override {
        if (!q || n_sent >= n_total || q->size() >= 2) return;
        CordicTxn t;
        t.id    = n_sent++;
        t.theta = int16_t(dth_(rng_));
        t.x0    = int16_t(dxy_(rng_));
        t.y0    = int16_t(dxy_(rng_));
        q->push_back(t);
    }
    bool done() const { return n_sent >= n_total; }

  private:
    std::mt19937 rng_{1};
    std::uniform_int_distribution<int> dth_{-PI_EXT, PI_EXT};
    std::uniform_int_distribution<int> dxy_{-6000, 6000};
};

// ---------------------------------------------------------------------------
//  4. Driver: an explicit two-state machine, one step per clock.
// ---------------------------------------------------------------------------
class CordicDrv : public Component {
  public:
    SVTLM_REGISTER(CordicDrv);
    CordicDrv(const std::string& n, Component* p) : Component(n, p) {}

    CordicVif*            vif = nullptr;
    std::deque<CordicTxn> q;
    unsigned              stall_pct = 0, n_driven = 0;

    void build() override {
        stall_pct = cfgInt("stall_pct", 0);
        rng_.seed(cfgInt("seed", 2));
    }
    void tick() override {
        Vcordic_rot* d = vif->dut;

        // --- request channel ------------------------------------------
        if (st_ == IDLE) {
            if (!q.empty()) {
                const CordicTxn& t = q.front();
                d->req_valid_i = 1;
                d->req_x_i     = uint16_t(t.x0);
                d->req_y_i     = uint16_t(t.y0);
                d->req_theta_i = uint16_t(t.theta);
                st_ = DRIVING;
            } else {
                d->req_valid_i = 0;
            }
        } else if (d->req_ready_o) {      // handshake completes on this edge
            q.pop_front();
            ++n_driven;
            d->req_valid_i = 0;
            st_ = IDLE;
        }

        // --- response channel: random back-pressure --------------------
        d->rsp_ready_i = (stall_pct == 0) || (int(rng_() % 100) >= int(stall_pct));
    }
    void report() override { info("drove %u transactions", n_driven); }

  private:
    enum State { IDLE, DRIVING } st_ = IDLE;
    std::mt19937 rng_{2};
};

// ---------------------------------------------------------------------------
//  5. Monitor: passive, publishes on an analysis port.
// ---------------------------------------------------------------------------
class CordicMon : public Component {
  public:
    SVTLM_REGISTER(CordicMon);
    CordicMon(const std::string& n, Component* p) : Component(n, p) {}

    CordicVif*             vif = nullptr;
    AnalysisPort<CordicTxn> ap;
    unsigned                n_seen = 0;

    void tick() override {
        Vcordic_rot* d = vif->dut;
        if (!d->rst_ni) { pending_.clear(); return; }

        if (d->req_valid_i && d->req_ready_o) {
            CordicTxn t;
            t.x0 = int16_t(d->req_x_i);
            t.y0 = int16_t(d->req_y_i);
            t.theta = int16_t(d->req_theta_i);
            t.id = n_seen++;
            pending_.push_back(t);
        }
        if (d->rsp_valid_o && d->rsp_ready_i) {
            if (pending_.empty()) { info("ERROR response with no request"); return; }
            CordicTxn t = pending_.front();
            pending_.pop_front();
            t.x = int16_t(d->rsp_x_o);
            t.y = int16_t(d->rsp_y_o);
            ap.write(t);                       // TLM broadcast
        }
    }
  private:
    std::deque<CordicTxn> pending_;
};

// ---------------------------------------------------------------------------
//  6. Scoreboard: subscribes to the analysis port, owns the golden model.
// ---------------------------------------------------------------------------
class CordicSb : public Component {
  public:
    SVTLM_REGISTER(CordicSb);
    CordicSb(const std::string& n, Component* p) : Component(n, p) {}

    unsigned checked = 0, failed = 0;
    double   worst = 0.0, tol = 12.0;

    void build() override { tol = cfgInt("tol_lsb", 12); }

    virtual void write(const CordicTxn& t) {
        double th = double(t.theta) / (1 << QA);
        double xr = double(t.x0) / (1 << QF), yr = double(t.y0) / (1 << QF);
        double rx = K_GAIN * (xr * std::cos(th) - yr * std::sin(th)) * (1 << QF);
        double ry = K_GAIN * (xr * std::sin(th) + yr * std::cos(th)) * (1 << QF);
        double ex = std::fabs(double(t.x) - rx), ey = std::fabs(double(t.y) - ry);
        worst = std::max(worst, std::max(ex, ey));
        ++checked;
        if (ex > tol || ey > tol) {
            ++failed;
            info("MISMATCH id=%u theta=%d got(%d,%d) want(%.1f,%.1f)",
                 t.id, t.theta, t.x, t.y, rx, ry);
        }
    }
    void report() override {
        info("%u checked, %u failed, worst %.2f LSB (tol %.0f)",
             checked, failed, worst, tol);
    }
};

// A second implementation of the same role, selected by a factory override.
class CordicSbStrict : public CordicSb {
  public:
    SVTLM_REGISTER(CordicSbStrict);
    CordicSbStrict(const std::string& n, Component* p) : CordicSb(n, p) {}
    void build() override { CordicSb::build(); tol = 2.0; }
    void report() override {
        info("STRICT mode: %u checked, %u failed, worst %.2f LSB (tol %.0f)",
             checked, failed, worst, tol);
    }
};

// ---------------------------------------------------------------------------
//  7. Coverage collector: also a subscriber of the same analysis port.
// ---------------------------------------------------------------------------
class CordicCov : public Component {
  public:
    SVTLM_REGISTER(CordicCov);
    CordicCov(const std::string& n, Component* p) : Component(n, p) {}

    unsigned bins[5] = {0, 0, 0, 0, 0};   // quadrant of theta

    void write(const CordicTxn& t) {
        int th = t.theta;
        if      (th < -PI_EXT / 2) bins[0]++;
        else if (th < 0)           bins[1]++;
        else if (th == 0)          bins[2]++;
        else if (th < PI_EXT / 2)  bins[3]++;
        else                       bins[4]++;
    }
    void report() override {
        unsigned hit = 0;
        for (unsigned b : bins) hit += (b != 0);
        info("theta bins hit %u/5  [%u %u %u %u %u]",
             hit, bins[0], bins[1], bins[2], bins[3], bins[4]);
    }
};

// ---------------------------------------------------------------------------
//  8. Agent and environment: pure structure, created through the factory.
// ---------------------------------------------------------------------------
class CordicAgent : public Component {
  public:
    SVTLM_REGISTER(CordicAgent);
    CordicAgent(const std::string& n, Component* p) : Component(n, p) {}

    CordicVif* vif = nullptr;
    CordicSeq* seq = nullptr;
    CordicDrv* drv = nullptr;
    CordicMon* mon = nullptr;

    void build() override {
        Factory& f = Factory::get();
        seq = f.createAs<CordicSeq>("CordicSeq", "seq", this);
        drv = f.createAs<CordicDrv>("CordicDrv", "drv", this);
        mon = f.createAs<CordicMon>("CordicMon", "mon", this);
        drv->vif = vif;
        mon->vif = vif;
    }
    void connect() override { seq->q = &drv->q; }
};

class CordicEnv : public Component {
  public:
    SVTLM_REGISTER(CordicEnv);
    CordicEnv(const std::string& n, Component* p) : Component(n, p) {}

    CordicVif*   vif = nullptr;
    CordicAgent* agt = nullptr;
    CordicSb*    sb  = nullptr;
    CordicCov*   cov = nullptr;

    void build() override {
        Factory& f = Factory::get();
        agt = f.createAs<CordicAgent>("CordicAgent", "agt", this);
        agt->vif = vif;
        sb  = f.createAs<CordicSb>("CordicSb", "sb", this);
        cov = f.createAs<CordicCov>("CordicCov", "cov", this);
    }
    void connect() override {
        // TLM: one producer, two consumers, no knowledge of each other.
        CordicSb*  s = sb;
        CordicCov* c = cov;
        agt->mon->ap.connect([s](const CordicTxn& t) { s->write(t); });
        agt->mon->ap.connect([c](const CordicTxn& t) { c->write(t); });
    }
};

#endif  // CORDIC_ENV_H_
