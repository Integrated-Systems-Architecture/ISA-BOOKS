// ===========================================================================
//  svtlm.h -- a very small UVM-shaped verification framework in C++.
//
//  Four ideas, and nothing else:
//    * Component   -- a named node in a tree, with build/connect/tick/report
//    * AnalysisPort-- one writer, many readers, TLM style
//    * Factory     -- create a component by type *name*, with overrides
//    * ConfigDb    -- a string-keyed store read during build()
// ===========================================================================
#ifndef SVTLM_H_
#define SVTLM_H_

#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <map>
#include <memory>
#include <string>
#include <vector>

namespace svtlm {

// ---------------------------------------------------------------------------
//  Configuration store.  The UVM equivalent is uvm_config_db#(T).
//  A key is "<component path>.<field>"; "*" matches any path.
// ---------------------------------------------------------------------------
class ConfigDb {
  public:
    static ConfigDb& get() { static ConfigDb db; return db; }

    void setInt(const std::string& path, const std::string& field, int v) {
        ints_[path + "." + field] = v;
    }
    void setStr(const std::string& path, const std::string& field,
                const std::string& v) {
        strs_[path + "." + field] = v;
    }
    bool getInt(const std::string& path, const std::string& field, int& v) const {
        auto it = ints_.find(path + "." + field);
        if (it == ints_.end()) it = ints_.find("*." + field);
        if (it == ints_.end()) return false;
        v = it->second;
        return true;
    }
    int getIntOr(const std::string& path, const std::string& field, int dflt) const {
        int v; return getInt(path, field, v) ? v : dflt;
    }
    bool getStr(const std::string& path, const std::string& field,
                std::string& v) const {
        auto it = strs_.find(path + "." + field);
        if (it == strs_.end()) it = strs_.find("*." + field);
        if (it == strs_.end()) return false;
        v = it->second;
        return true;
    }
  private:
    std::map<std::string, int>         ints_;
    std::map<std::string, std::string> strs_;
};

// ---------------------------------------------------------------------------
//  Analysis port.  uvm_analysis_port#(T) with the boilerplate removed:
//  a subscriber is any callable, so a lambda that forwards to a method is
//  enough and no *_imp class is needed.
// ---------------------------------------------------------------------------
template <typename T>
class AnalysisPort {
  public:
    using Sub = std::function<void(const T&)>;
    void connect(Sub s) { subs_.push_back(std::move(s)); }
    void write(const T& t) const { for (const auto& s : subs_) s(t); }
    size_t nsubs() const { return subs_.size(); }
  private:
    std::vector<Sub> subs_;
};

// ---------------------------------------------------------------------------
//  Component: the phase machinery.
//
//  UVM's build_phase is top-down, connect_phase bottom-up, run_phase
//  concurrent.  Here build() is top-down (a parent creates its children),
//  connect() is bottom-up, tick() is called once per clock on every
//  component in construction order, and report() runs at the end.
// ---------------------------------------------------------------------------
class Component {
  public:
    Component(std::string name, Component* parent)
        : name_(std::move(name)), parent_(parent) {
        if (parent_) parent_->children_.push_back(this);
    }
    virtual ~Component() = default;

    const std::string& name() const { return name_; }
    Component*         parent() const { return parent_; }

    std::string fullName() const {
        return parent_ ? parent_->fullName() + "." + name_ : name_;
    }

    // ---- the phases, overridden by the user ----------------------------
    virtual void build()   {}
    virtual void connect() {}
    virtual void tick()    {}
    virtual void report()  {}

    // ---- the phase walkers, called by the test -------------------------
    void buildAll() {
        build();
        // build() may have created children, so index the vector by hand.
        for (size_t i = 0; i < children_.size(); ++i) children_[i]->buildAll();
    }
    void connectAll() {                     // bottom-up, like UVM
        for (auto* c : children_) c->connectAll();
        connect();
    }
    void tickAll() {
        tick();
        for (auto* c : children_) c->tickAll();
    }
    void reportAll() {
        for (auto* c : children_) c->reportAll();
        report();
    }
    void printTree(int depth = 0) const {
        printf("%*s%s (%s)\n", depth * 2, "", name_.c_str(), typeName().c_str());
        for (const auto* c : children_) c->printTree(depth + 1);
    }
    virtual std::string typeName() const { return "Component"; }

    // ---- reporting -----------------------------------------------------
    void info(const char* fmt, ...) const;

    int cfgInt(const std::string& field, int dflt) const {
        return ConfigDb::get().getIntOr(fullName(), field, dflt);
    }

  protected:
    std::vector<Component*> children_;
  private:
    std::string name_;
    Component*  parent_;
};

inline void Component::info(const char* fmt, ...) const {
    va_list ap;
    va_start(ap, fmt);
    printf("[%-22s] ", fullName().c_str());
    vprintf(fmt, ap);
    printf("\n");
    va_end(ap);
}

// ---------------------------------------------------------------------------
//  Factory.  uvm_factory with one type of override: by type name.
// ---------------------------------------------------------------------------
class Factory {
  public:
    using Ctor = std::function<Component*(const std::string&, Component*)>;

    static Factory& get() { static Factory f; return f; }

    void reg(const std::string& type, Ctor c) { ctors_[type] = std::move(c); }
    void setTypeOverride(const std::string& orig, const std::string& repl) {
        overrides_[orig] = repl;
    }
    Component* create(const std::string& type, const std::string& name,
                      Component* parent) {
        std::string t = type;
        auto ov = overrides_.find(t);
        if (ov != overrides_.end()) t = ov->second;
        auto it = ctors_.find(t);
        if (it == ctors_.end()) {
            printf("FATAL: factory has no type '%s'\n", t.c_str());
            abort();
        }
        return it->second(name, parent);
    }
    template <typename T>
    T* createAs(const std::string& type, const std::string& name,
                Component* parent) {
        return static_cast<T*>(create(type, name, parent));
    }
  private:
    std::map<std::string, Ctor>        ctors_;
    std::map<std::string, std::string> overrides_;
};

// Registration helper: one static object per component type.
// The UVM counterpart is the `uvm_component_utils macro.
template <typename T>
struct Registrar {
    explicit Registrar(const std::string& type) {
        Factory::get().reg(type, [](const std::string& n, Component* p) {
            return static_cast<Component*>(new T(n, p));
        });
    }
};

#define SVTLM_REGISTER(TYPE)                                     \
    std::string typeName() const override { return #TYPE; }      \
    static inline svtlm::Registrar<TYPE> svtlm_reg_{#TYPE}

}  // namespace svtlm
#endif  // SVTLM_H_
