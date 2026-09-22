# Reading list — reference accelerators

Papers to take ideas from while you design your accelerator. They are not
required reading: pick the section for your application and the section for
the lab you are in, start from the ★ entries, and skim the rest when you need a
specific idea. Each entry says what to take from it.

Every link goes to IEEE Xplore. From the Politecnico network (or the VPN) you
can download the full text; from home, most of these papers also have an
author copy or an arXiv version — search the title.

Groups are noted in brackets where they matter: **PULP** (L. Benini, F. Conti,
D. Rossi — ETH Zürich / Univ. Bologna), **ESL** (D. Atienza, P. D. Schiavone —
EPFL), **SLD** (L. Carloni — Columbia), **UPM** (Universidad Politécnica de
Madrid), **PoliTo** (this department).

Contents:

1. [Integrating an accelerator in an SoC](#1-integrating-an-accelerator-in-an-soc) — everyone, Labs 0, 1, 3
2. [rxchain — CORDIC, FIR, decimation, isqrt](#2-rxchain--cordic-fir-decimation-isqrt)
3. [tinydnn — convolution and linear layers](#3-tinydnn--convolution-and-linear-layers)
4. [tinyformer — matmul, softmax, attention](#4-tinyformer--matmul-softmax-attention)
5. [pqcrypto — NTT and modular arithmetic](#5-pqcrypto--ntt-and-modular-arithmetic)
6. [Fixed point: how many bits](#6-fixed-point-how-many-bits)
7. [Optimization: retiming, pipelining, folding, arithmetic](#7-optimization-retiming-pipelining-folding-arithmetic) — Lab 2

---

## 1. Integrating an accelerator in an SoC

Every accelerator in this course is a memory-mapped peripheral: CSRs for
control, OBI for data. These papers explain why that shape wins for kernels
that work on blocks of data, and show real register maps and data ports.

- ★ **An Analysis of Accelerator Coupling in Heterogeneous Architectures** —
  E. G. Cota, P. Mantovani, G. Di Guglielmo, L. P. Carloni (SLD), *DAC* 2015.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/7167228).
  Accelerators inside the core pipeline vs on the bus with their own DMA and
  scratchpad: when each wins. The argument behind this course's CSR + OBI choice.
- ★ **Agile SoC Development with Open ESP** — P. Mantovani et al., L. P. Carloni
  (SLD), *ICCAD* 2020.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/9256819).
  How an accelerator is wrapped in a standard socket: configuration registers,
  DMA, interrupt, driver. Very close to what you build in Labs 1 and 3.
- **Accelerators and Coherence: An SoC Perspective** — D. Giri, P. Mantovani,
  L. P. Carloni (SLD), *IEEE Micro* 2018.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/8525419).
  What happens to the data an accelerator reads and writes when caches are
  involved; non-coherent DMA vs coherent access, and when each pays off.
- ★ **X-HEEP: An Open-Source, Configurable and Extendible RISC-V Platform for
  TinyAI Applications** — S. Machetti, P. D. Schiavone, …, D. Atienza (ESL),
  *ISVLSI* 2025.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/11130281).
  The platform you integrate into: bus, memory banks, DMA, power domains, and
  the interface it offers to external accelerators.
- ★ **An IoT Endpoint System-on-Chip for Secure and Energy-Efficient
  Near-Sensor Analytics** (Fulmine) — F. Conti, …, D. Rossi, L. Benini (PULP),
  *IEEE TCAS-I* 2017.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/7927716).
  A convolution engine and a crypto engine (AES, Keccak) programmed through
  memory-mapped registers and fetching their own data from shared memory.
- **XNOR Neural Engine: A Hardware Accelerator IP for 21.6-fJ/op Binary Neural
  Network Inference** — F. Conti, P. D. Schiavone, L. Benini (PULP),
  *IEEE TCAD* 2018.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/8412533).
  One accelerator IP described end to end: register file, controller, a master
  port into the microcontroller's SRAM, datapath. The same shape as an OBI-master
  accelerator.
- **Scalable and RISC-V Programmable Near-Memory Computing Architectures for
  Edge Nodes** (NM-Caesar / NM-Carus) — M. Caon, …, G. Masera, M. Martina,
  D. Atienza (ESL, PoliTo), *IEEE TETC* 2025.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/10964076).
  Two accelerators built into X-HEEP as memory-mapped OBI slaves, with the
  software stack and measured gains.
- **X-TRELA: An Open-Source Streaming Elastic CGRA With ASIC Implementation for
  the Edge** — D. Vázquez, J. Miranda, A. Rodríguez, A. Otero (UPM),
  *IEEE Access* 2026.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/11577129).
  A reconfigurable accelerator attached to X-HEEP and taped out: memory-mapped
  configuration, streaming data over the bus, measured energy. Open source.
- **Exploiting Hardware-Based Data-Parallel and Multithreading Models for Smart
  Edge Computing in Reconfigurable FPGAs** (ARTICo3) — A. Rodríguez, A. Otero,
  M. Platzner, E. de la Torre (UPM), *IEEE TC* 2022.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/9524488).
  Many copies of one accelerator behind a single register + DMA interface, and
  the runtime that drives them. Useful for thinking about the driver side.

## 2. rxchain — CORDIC, FIR, decimation, isqrt

- **The CORDIC Trigonometric Computing Technique** — J. E. Volder,
  *IRE Trans. Electronic Computers* 1959.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/5222693).
  The original: rotation by shifts and adds. Short and readable.
- ★ **50 Years of CORDIC: Algorithms, Architectures, and Applications** —
  P. K. Meher et al., *IEEE TCAS-I* 2009.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/5089431).
  The map of the design space: iterative vs unrolled vs pipelined, scale-factor
  compensation, redundant arithmetic.
- **Uniformly Distributed CORDIC** — M. Garrido, D. Medina, P. Paz,
  M. López-Vallejo (UPM), *IEEE TCAS-I* 2025.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/10972359).
  A recent CORDIC rotator that rethinks how the angle is split across stages.
- **Methods of Mapping from Phase to Sine Amplitude in Direct Digital
  Synthesis** — J. Vankka, *IEEE Trans. UFFC* 1997.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/585137).
  The alternatives to CORDIC for an NCO (lookup tables, compression,
  polynomials) and their precision and spur trade-offs.
- ★ **An Economical Class of Digital Filters for Decimation and Interpolation** —
  E. B. Hogenauer, *IEEE TASSP* 1981.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/1163535).
  The CIC filter: decimation with no multipliers, and how register width grows.
- **Applications of Distributed Arithmetic to Digital Signal Processing: A
  Tutorial Review** — S. A. White, *IEEE ASSP Magazine* 1989.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/29648).
  FIR filters with lookup tables and shift-accumulate instead of multipliers.
- **Subexpression Sharing in Filters Using Canonic Signed Digit Multipliers** —
  R. I. Hartley, *IEEE TCAS-II* 1996.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/539000).
  Constant coefficients as shifts and adds, shared across taps. The FIR's fixed
  coefficients are exactly this case.
- **Use of Minimum-Adder Multiplier Blocks in FIR Digital Filters** —
  A. G. Dempster, M. D. Macleod, *IEEE TCAS-II* 1995.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/466647).
  Multiplying one input by many constants with as few adders as possible;
  complements Hartley.
- **A New Non-Restoring Square Root Algorithm and Its VLSI Implementations** —
  Y. Li, W. Chu, *ICCD* 1996.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/563604).
  Integer square root with add/subtract only, in an iterative and a pipelined
  version — the magnitude stage of the receiver.

## 3. tinydnn — convolution and linear layers

- ★ **Why Systolic Architectures?** — H. T. Kung, *IEEE Computer* 1982.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/1653825).
  The founding argument: reuse each fetched operand many times so compute is
  not starved by memory.
- ★ **Efficient Processing of Deep Neural Networks: A Tutorial and Survey** —
  V. Sze, Y.-H. Chen, T.-J. Yang, J. Emer, *Proc. IEEE* 2017.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/8114708).
  Convolution as loop nests; weight-, output- and row-stationary dataflows; why
  memory accesses, not MACs, dominate energy.
- **Eyeriss: A Spatial Architecture for Energy-Efficient Dataflow for
  Convolutional Neural Networks** — Y.-H. Chen, J. Emer, V. Sze, *ISCA* 2016.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/7551407).
  The dataflow comparison in depth.
- **Eyeriss: An Energy-Efficient Reconfigurable Accelerator for Deep
  Convolutional Neural Networks** — Y.-H. Chen, T. Krishna, J. Emer, V. Sze,
  *IEEE JSSC* 2017.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/7738524).
  The chip: PE array, on-chip network, global buffer.
- **Vega: A Ten-Core SoC for IoT Endnodes With DNN Acceleration and Cognitive
  Wake-Up From MRAM-Based State-Retentive Sleep Mode** — D. Rossi, …,
  L. Benini (PULP), *IEEE JSSC* 2022.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/9560136).
  A 4/8/16-bit convolution engine sharing memory with the cores, in silicon.
- **Marsellus: A Heterogeneous RISC-V AI-IoT End-Node SoC With 2–8 b DNN
  Acceleration and 30%-Boost Adaptive Body Biasing** — F. Conti, …,
  L. Benini (PULP), *IEEE JSSC* 2024.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/10269153).
  A precision-scalable DNN engine; how bit-width becomes a design parameter.
- **Self-Reconfigurable Evolvable Hardware System for Adaptive Image
  Processing** — R. Salvador, A. Otero, J. Mora, E. de la Torre, T. Riesgo
  (UPM), L. Sekanina, *IEEE TC* 2013.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/6494560).
  A systolic array of processing elements for 2-D windows on images. Optional.
- See also Fulmine and XNOR Neural Engine in [section 1](#1-integrating-an-accelerator-in-an-soc).

## 4. tinyformer — matmul, softmax, attention

In `tinyformer` the matmuls are about 80% of the run and softmax about 1%:
read the matmul papers first.

- ★ **ITA: An Energy-Efficient Attention and Softmax Accelerator for Quantized
  Transformers** — G. Islamoglu, …, L. Benini (PULP), *ISLPED* 2023.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/10244348).
  An int8 attention datapath with an integer streaming softmax — the closest
  match to `tinyformer`.
- **Toward Attention-Based TinyML: A Heterogeneous Accelerated Architecture and
  Automated Deployment Flow** — P. Wiese, …, F. Conti, L. Benini (PULP),
  *IEEE Design & Test* 2025.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/10833747).
  ITA integrated next to RISC-V cores, running whole int8 transformers.
- ★ **Softermax: Hardware/Software Co-Design of an Efficient Softmax for
  Transformers** — J. R. Stevens et al., *DAC* 2021.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/9586134).
  Softmax for integer hardware: base-2 exponent, running maximum, low-precision
  normalization.
- **A^3: Accelerating Attention Mechanisms in Neural Networks with
  Approximation** — T. J. Ham et al., *HPCA* 2020.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/9065498).
  Attention as a hardware pipeline: dot product, exponent, weighted sum.
- **SpAtten: Efficient Sparse Attention Architecture with Cascade Token and
  Head Pruning** — H. Wang, Z. Zhang, S. Han, *HPCA* 2021.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/9407232).
  An attention accelerator that skips work it can prove is unimportant.
- **RedMulE: A Compact FP16 Matrix-Multiplication Accelerator for Adaptive Deep
  Learning on RISC-V-Based Ultra-Low-Power SoCs** — Y. Tortorella, …,
  F. Conti (PULP), *DATE* 2022.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/9774759).
  A matmul engine next to RISC-V cores. Floating point, but the array
  organization and the memory interface carry over to int8.
- **A Flexible Template for Edge Generative AI With High-Accuracy Accelerated
  Softmax and GELU** (SoftEx) — A. Belano, …, F. Conti, L. Benini (PULP),
  *IEEE JETCAS* 2025.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/10971415).
  A softmax/GELU unit placed next to a matmul engine. BF16; for the
  architecture, not the number format.

## 5. pqcrypto — NTT and modular arithmetic

In `pqcrypto` the forward and inverse NTTs are about 82% of the run. An NTT is
an FFT over integers modulo q, so the FFT architecture papers apply directly.

- ★ **An Extensive Study of Flexible Design Methods for the Number Theoretic
  Transform** — A. C. Mert et al., *IEEE TC* 2022.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/9171507).
  The tutorial: butterfly arrangement, memory banking and conflict-free access,
  modular reduction choices.
- **High-Speed Polynomial Multiplication Architecture for Ring-LWE and SHE
  Cryptosystems** — D. D. Chen, …, S. S. Roy, I. Verbauwhede,
  *IEEE TCAS-I* 2015.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/6918547).
  A classic pipelined NTT/INTT: butterfly pipeline and twiddle factors.
- **KaLi: A Crystal for Post-Quantum Security Using Kyber and Dilithium** —
  A. Aikata, …, S. Pagliarini, S. S. Roy, *IEEE TCAS-I* 2023.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/9946370).
  One unified NTT datapath serving two schemes, Kyber included.
- **High-Speed NTT-based Polynomial Multiplication Accelerator for Post-Quantum
  Cryptography** — M. Bisheh-Niasar, R. Azarderakhsh, M. Mozaffari-Kermani,
  *ARITH* 2021.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/9603378).
  A Kyber NTT with several butterfly cores and a light modular reduction for
  q = 3329.
- **An Energy-Efficient Configurable Lattice Cryptography Processor for the
  Quantum-Secure Internet of Things** — U. Banerjee, A. Pathak,
  A. P. Chandrakasan, *ISSCC* 2019.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/8662528).
  A low-power lattice crypto processor in silicon: NTT, sampling, energy per
  operation.
- **A New Approach to Pipeline FFT Processor** — S. He, M. Torkelson, *IPPS* 1996.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/508145).
  The single-delay-feedback pipelined FFT; the same structure works for an NTT.
- **Pipelined Radix-2^k Feedforward FFT Architectures** — M. Garrido,
  J. Grajal, M. A. Sánchez (UPM), O. Gustafsson, *IEEE TVLSI* 2013.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/6118316).
  Feedforward (multi-path) pipelined FFTs: trading parallelism for throughput.
- **Analyzing and Comparing Montgomery Multiplication Algorithms** —
  Ç. K. Koç, T. Acar, B. S. Kaliski, *IEEE Micro* 1996.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/502403).
  The standard tutorial on Montgomery reduction, for the pointwise multiply and
  the butterflies.

## 6. Fixed point: how many bits

The kernels are integer (int8, int32, Q15, Q1.14). Every internal register has
a width you have to justify.

- **Improved Interval-Based Characterization of Fixed-Point LTI Systems With
  Feedback Loops** — J. A. López, C. Carreras, O. Nieto-Taladriz (UPM),
  *IEEE TCAD* 2007.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/4352008).
  Bounding the range and round-off noise of a filter analytically, before
  writing RTL.
- **Optimal Combined Word-Length Allocation and Architectural Synthesis of
  Digital Signal Processing Circuits** — G. Caffarena (UPM),
  G. A. Constantinides, P. Y. K. Cheung, C. Carreras, O. Nieto-Taladriz (UPM),
  *IEEE TCAS-II* 2006.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/1632340).
  Choosing bit-widths and sharing hardware at the same time.
- **Advanced Quantization Schemes to Increase Accuracy, Reduce Area, and Lower
  Power Consumption in FFT Architectures** — M. Garrido, V. M. Bautista (UPM),
  A. Portas, J. Hormigo, *IEEE TCAS-I* 2025.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/10596051).
  Truncation vs rounding vs biased formats, and how the choice moves accuracy,
  area and power together.

## 7. Optimization: retiming, pipelining, folding, arithmetic

For Lab 2. These are the original sources of the techniques you apply.

- **Optimizing Synchronous Systems** — C. E. Leiserson, J. B. Saxe, *FOCS* 1981.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/4568313).
  Retiming: moving registers without changing behaviour.
- **Pipeline Interleaving and Parallelism in Recursive Digital Filters — Part I:
  Pipelining Using Scattered Look-Ahead and Decomposition** — K. K. Parhi,
  D. G. Messerschmitt, *IEEE TASSP* 1989.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/32286).
  How to pipeline a loop with feedback, where adding registers alone breaks it.
- **Synthesis of Control Circuits in Folded Pipelined DSP Architectures** —
  K. K. Parhi, C.-Y. Wang, A. P. Brown, *IEEE JSSC* 1992.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/109555).
  Folding: time-sharing operations on fewer units, and the control it needs.
- **A Suggestion for a Fast Multiplier** — C. S. Wallace,
  *IEEE Trans. Electronic Computers* 1964.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/4038071).
  Carry-save adder trees for partial products.
- **High-Speed Arithmetic in Binary Computers** — O. L. MacSorley,
  *Proc. IRE* 1961.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/4066249).
  Modified (radix-4) Booth recoding, carry-lookahead and carry-save, from the
  source.
- **A Formal Method for Optimal High-Level Casting of Heterogeneous Fixed-Point
  Adders and Subtractors** — R. Sierra, C. Carreras, G. Caffarena,
  C. A. López Barrio (UPM), *IEEE TCAD* 2015.
  [IEEE Xplore](https://ieeexplore.ieee.org/document/6936317).
  Sizing and aligning adders whose operands have different formats — the
  accumulator trees in FIR, matmul and requantization.
- For constant multiplication, see Hartley and Dempster–Macleod in
  [section 2](#2-rxchain--cordic-fir-decimation-isqrt).
