# Author guide — *SystemVerilog for VHDL Designers: A Cookbook*

Read this completely before writing a single line of LaTeX.

## 1. Audience and voice

Final-year MSc students in electronic engineering at Politecnico di Torino.
They have used **VHDL for their entire degree** and are meeting SystemVerilog
for the first time in their last course. They are competent digital designers.
They know processes, signals vs. variables, `numeric_std`, generics, generate
statements, and the classic VHDL testbench (`wait for`, `assert ... report`).
They know nothing about Verilog, classes, constrained random, UVM, Verilator or
cocotb.

So:

- **Always explain the new thing in terms of the VHDL they already know.**
  Never introduce a SystemVerilog construct without saying what it replaces,
  what it adds, or what has no counterpart.
- Assume competence, not knowledge. Do not explain what a flip-flop is; do
  explain why `logic` is not `std_logic`.
- Direct academic English. Short sentences. Active voice.
- **Banned words and phrasings** (author preference, non-negotiable):
  "orchestration", "orchestrate", "hinges", "alongside", "scenario",
  "leverage", "delve", "landscape", "seamless", "robust" (as filler),
  "it's worth noting that", "in today's world". Also avoid compound list
  constructions of the shape "X, Y, and Z alike" or "not only ... but also".
- Do not use em dashes as a stylistic tic. Prefer a comma, a colon, or a new
  sentence. Where a dash is genuinely right, use `--` (en dash) sparingly.
- No emoji. No exclamation marks.
- Write British-neutral spelling consistently (`behaviour`, `analyse`,
  `initialise`) — but keep code and standard terminology as-is
  (`always_comb`, `initial`, `behavioral` inside a VHDL architecture name).

## 2. What a chapter must contain

Every chapter file starts with:

```latex
\chapter{Title Of The Chapter}
\label{ch:short-key}

\chapabstract{Two to four sentences: what this chapter answers, and what the
reader will be able to do at the end of it.}
```

and ends with a short section:

```latex
\section{Checklist}
\label{sec:short-key:checklist}
```

containing a compact bulleted list of the operational takeaways ("when you see
X in VHDL, write Y"; "never do Z").

In between: sections, real code, and real explanations. **Every claim about
language behaviour must be demonstrated with code.** No hand-waving.

Aim for the target length given in your individual brief. Depth beats breadth,
but the chapter must cover its whole assigned scope.

## 3. LaTeX conventions — follow exactly

### Absolutely forbidden in a chapter file

- `\usepackage` (all packages are loaded in `preamble/packages.tex`)
- `\documentclass`, `\begin{document}`
- raw `\begin{lstlisting}` (use the environments below)
- redefining any macro
- `\newcommand` (if you genuinely need one, put it *inside* your chapter file
  with a chapter-specific name, e.g. `\newcommand{\chFourFoo}{...}`)

### Code environments (these are the only ones you may use)

```latex
\begin{svcode}[caption={What this shows},label={lst:key:name}]
...SystemVerilog...
\end{svcode}

\begin{vhdlcode}[caption={...},label={lst:key:name}]
...VHDL...
\end{vhdlcode}

\begin{uvmcode}[caption={...},label={lst:key:name}]   % SV + UVM highlighting
\begin{cppcode}[caption={...},label={lst:key:name}]
\begin{pycode}[caption={...},label={lst:key:name}]
\begin{shcode}                                        % shell commands, no caption needed
\begin{makecode}                                      % Makefile fragments
\begin{tclcode}                                       % Questa/Vivado Tcl
\begin{txtcode}                                       % plain output, logs, tables
```

`caption` and `label` are optional; use them whenever you refer to the listing
from the text. Label format: `lst:<chapter-key>:<name>`.

### Side-by-side VHDL / SystemVerilog comparison

This is the signature device of the book. Use it heavily in Chapters 2 and 3.

```latex
\begin{rosetta}
\begin{rleft}
process (clk) is
begin
  if rising_edge(clk) then
    q <= d;
  end if;
end process;
\end{rleft}
\begin{rright}
always_ff @(posedge clk) begin
  q <= d;
end
\end{rright}
\end{rosetta}
```

The left pane is **always VHDL**, the right pane is **always SystemVerilog**;
the pane titles are added automatically. Each pane is about **38 characters
wide** — keep the lines short or they will wrap ugly. No line numbers appear
in these panes. Do not put a caption on a `rosetta`; introduce it in the
sentence before, and comment on it in the sentence after.

### Admonition boxes

```latex
\begin{gotcha}{Short title}      % a trap that specifically catches VHDL people
\end{gotcha}

\begin{tipbox}{Short title}      % a recipe: "do it like this"
\end{tipbox}

\begin{notebox}{Short title}     % background, history, standards trivia
\end{notebox}

\begin{ruleofthumb}              % one or two lines, no title
\end{ruleofthumb}
```

Use `gotcha` liberally — three to six per chapter is right. They are the most
valuable thing in the book for this audience.

### Inline markup

- `\code{always_comb}` — any code identifier in running text
- `\kw{logic}` — a language keyword you want to emphasise
- `\file{cordic_rot.sv}` — a file name
- `\tool{QuestaSim}`, `\tool{Verilator}`, `\tool{GHDL}` — tool names
- `\SV` expands to "SystemVerilog", `\VHDL` to "VHDL". Use them.

Underscores inside `\code{}` are fine (it is `\texttt`), but in ordinary text
you must escape them: `\_`.

### Figures

Draw real TikZ where the picture carries explanatory weight. Use

```latex
\begin{figure}[htbp]
  \centering
  \begin{tikzpicture}[...]
    ...
  \end{tikzpicture}
  \caption{...}
  \label{fig:key:name}
\end{figure}
```

The following TikZ libraries are already loaded: `arrows.meta, positioning,
fit, calc, shapes.geometric, shapes.misc, backgrounds,
decorations.pathreplacing, decorations.pathmorphing, patterns, chains,
matrix`. `pgfplots` (compat 1.18) and `tikz-timing` are available.

Colours you may use: `codekey` (blue), `accent` (green), `accentalt` (rust),
`codeframe` (light grey rule), `codebg`, `vhdlbg`, `svbg`, `notebg`, `tipbg`,
`warnbg`, `noteframe`, `tipframe`, `warnframe`, plus anything from
`dvipsnames`.

Where a screenshot or an externally sourced drawing belongs, use

```latex
\placeholder{5cm}{A screenshot of the QuestaSim wave window showing the
req_valid/req_ready handshake.}
```

Keep TikZ **simple and robust**. A figure that fails to compile is worse than
no figure. Do not use `\tikzmark`, `remember picture`, `overlay`, or external
`.png`/`.pdf` files.

### Tables

`booktabs` only (`\toprule`, `\midrule`, `\bottomrule`). No vertical rules.
Long two-column mapping tables are welcome — use `longtable` with
`\endfirsthead`/`\endhead` if they may break across pages.

### Cross references

`\cref{ch:...}`, `\cref{sec:...}`, `\cref{lst:...}`, `\cref{fig:...}`,
`\cref{tab:...}`. Do **not** write "Chapter~\ref{...}".

You may reference other chapters by these labels, which are guaranteed to
exist:

| label | chapter |
|---|---|
| `ch:philosophy` | 1. Two Languages, Two Philosophies |
| `ch:rosetta` | 2. The Rosetta Stone |
| `ch:beyond` | 3. Beyond VHDL |
| `ch:tb` | 4. Testbenches Without UVM |
| `ch:uvm` | 5. UVM Basics |
| `ch:verilator` | 6. Verilator |
| `ch:python` | 7. Python and Testbenches |
| `ch:case` | 8. The Complete Example |
| `app:cheatsheet` | Appendix A. Quick Reference |
| `app:tooling` | Appendix B. Tool Setup |

### Index

Add `\index{term}` for genuinely important terms — roughly 15 to 30 per
chapter. Use `\index{always\_comb}` style escaping. Nest with
`\index{assertion!immediate}`.

## 4. Technical accuracy rules

- Target **IEEE 1800-2017** (SystemVerilog) and **IEEE 1076-2008** (VHDL).
  Where VHDL-2019 matters (interfaces, mode views), say so explicitly and
  warn that tool support is thin.
- Be honest about tool support. If Verilator does not implement a feature,
  say so. If a construct is legal but poorly supported, say so.
- Do not invent syntax. If you are not certain a construct is legal, either
  check it or do not use it.
- Do not claim performance numbers you cannot justify. Where you give an
  order of magnitude, frame it as such ("typically one to two orders of
  magnitude" rather than "47x faster").
- SystemVerilog gotchas the book must get right and repeat: `logic` vs `wire`
  vs `reg`; blocking (`=`) vs non-blocking (`<=`); signed vs unsigned and the
  self-determined/context-determined width rules; `>>` vs `>>>`; the event
  scheduler regions; `always_comb` sensitivity; the class handle being a
  reference; static vs automatic lifetime.

## 5. The running example

Chapters may refer to the CORDIC rotator used in \cref{ch:case}. Its interface
is fixed:

```
module cordic_rot #(parameter int unsigned ITER = 14) (
  input  logic clk_i, rst_ni,
  input  logic req_valid_i,  output logic req_ready_o,
  input  data_t req_x_i, req_y_i,  input angle_t req_theta_i,
  output logic rsp_valid_o,  input  logic rsp_ready_i,
  output data_t rsp_x_o, rsp_y_o
);
```

`data_t` is `logic signed [15:0]` (Q1.14), `angle_t` is `logic signed [15:0]`
(Q2.13 radians). Package `cordic_pkg` holds the formats and the arctangent
ROM. Do not redefine it; refer to it.

Small illustrative examples in Chapters 1-7 do **not** have to use the CORDIC.
Use whatever is clearest: counters, FIFOs, shift registers, an ALU. Keep them
tiny.

## 6. Output

Write **one file only**: `chapters/<your-folder>/chapter.tex`. It must compile
as part of the book with no other change. Verify it yourself by running, from
the repository root:

```
pdflatex -interaction=nonstopmode -halt-on-error main.tex
```

Do not edit `main.tex`, the preamble, the `code/` tree, or any other chapter.
