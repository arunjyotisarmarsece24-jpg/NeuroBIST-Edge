# NeuroBIST-Edge: A Fault-Tolerant Neuromorphic Spiking-Residue Processor with Autonomous Silicon BIST and Asynchronous CDC Ingestion

[![FPGA](https://img.shields.io/badge/FPGA-AMD_Spartan--7_XC7S25-blue.svg)](https://www.xilinx.com/products/silicon-devices/fpga/spartan-7.html)
[![Board](https://img.shields.io/badge/Board-Digilent_Arty_S7--25-orange.svg)](https://digilent.com/reference/programmable-logic/arty-s7/start)
[![Transceiver](https://img.shields.io/badge/Edge_MCU-Espressif_ESP8266-red.svg)](https://www.espressif.com/en/products/socs/esp8266)
[![Toolchain](https://img.shields.io/badge/EDA-Vivado_2025.2-purple.svg)](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html)
[![Verification](https://img.shields.io/badge/Timing_Closure-WNS_>_4.9ns-success.svg)]()
[![License](https://img.shields.io/badge/License-MIT_Research-green.svg)]()

> **Project Architecture:** Hardware-Software Co-Design for Industrial Edge IoT, Neuromorphic Computing, and Autonomous Silicon Diagnostics  
> **Target Silicon:** Digilent Arty S7-25 (AMD Spartan-7 XC7S25-CSGA324-1)  
> **Wireless Ingestion Bridge:** Espressif ESP8266 (3.3V LVCMOS Interconnect via PMOD JA)  
> **Directory:** `C:\Users\IITBHU RESEARCH LAB\OneDrive\Desktop\Arunjyoti_Sarma\My_Coding_files\Day_1\Summarise_Work`

---

## 1. Architectural Philosophy & Executive Abstract

Modern edge-computing devices in safety-critical cyber-physical systems (automotive telemetry, industrial automation, edge AI robotics) face four simultaneous, interrelated challenges:
1. **Clock Domain Crossing (CDC) Metastability & Line Noise:** Asynchronous signals arriving over physical board-to-board interconnects suffer from ground bounce, electromagnetic interference (EMI), and setup/hold timing violations.
2. **Buffering Latency Bottlenecks:** Conventional software systems must buffer full network packets before running Cyclic Redundancy Checks (CRC), making them vulnerable to memory exhaustion and microsecond-level denial-of-service (DoS) bursts.
3. **Silicon Aging & In-Field Fault Coverage:** Hardware nodes deployed in hostile environments require continuous, autonomous Built-In Self-Test (BIST) capabilities to detect single-event upsets (SEUs) and physical silicon degradation without halting system clocks.
4. **Neuromorphic Event Stream Processing:** High-throughput event-based sensor streams require energy-efficient, spike-driven Leaky Integrate-and-Fire (LIF) neural models that adapt dynamically to distributed network noise.

**NeuroBIST-Edge** solves these challenges by unifying **three synthesizable hardware layers** with **three algorithmic software engines**, synchronized through an **ESP8266 wireless edge transceiver** and verified on an **AMD Spartan-7 FPGA**.

```
                           +-------------------------------------------------+
                           |        ESP8266 Wireless Edge Gateway            |
                           |  - Ingests 802.11 b/g/n Telemetry Packets       |
                           |  - Generates Asynchronous Neuromorphic Spikes   |
                           +-----------------------+-------------------------+
                                                   |
                                 Asynchronous Bus  | Physical Pin (PMOD JA1)
                                 (Raw GPIO / UART) | (Subject to Ringing & EMI)
                                                   v
+----------------------------------------------------------------------------------------------------+
|                                    AMD SPARTAN-7 FPGA HARDWARE                                     |
|                                                                                                    |
|   +--------------------------------------------------------------------------------------------+   |
|   | TIER 1: PHYSICAL ASYNCHRONOUS INGESTION & CDC STABILIZATION                                |   |
|   |   - 2-Stage Flip-Flop Synchronizer suppresses 100 MHz Clock Domain Crossing metastability  |   |
|   |   - 2-Sample Consecutive Filter rejects line ringing / EMI glitches shorter than 20 ns     |   |
|   |   - Single-Cycle Edge-Triggered Strobe Generator (10 ns pulse)                             |   |
|   +----------------------------------------------+---------------------------------------------+   |
|                                                  | Glitch-Free Synchronized Spikes                 |
|                                                  v                                                 |
|   +--------------------------------------------------------------------------------------------+   |
|   | TIER 2: HARDWARE BUILT-IN SELF-TEST (BIST) & NEUROMORPHIC CORE                             |   |
|   |                                                                                            |   |
|   |   +------------------------------------+   +-------------------------------------------+   |   |
|   |   | AUTONOMOUS SILICON BIST ENGINE     |   | DIGITAL LEAKY INTEGRATE-AND-FIRE (LIF)    |   |   |
|   |   |   - 16-Bit Galois LFSR PRBS Gen    |   |   - Vmem[t+1] = Vmem - (Vmem>>2) + W*Spk  |   |   |
|   |   |   - 16-Bit MISR Signature Analyzer |   |   - Dynamic Synaptic Weight Modulation    |   |   |
|   |   |   - 64 Test Vectors / Golden CRC   |   |   - Threshold Firing & Hyperpolarization  |   |   |
|   |   +------------------------------------+   +-------------------------------------------+   |   |
|   |                      |                                       |                             |   |
|   |                      v                                       v                             |   |
|   |   +------------------------------------+   +-------------------------------------------+   |   |
|   |   | SLIDING-WINDOW BURST MATCHER       |   | LINE-RATE MODULO-3 RESIDUE INVARIANT      |   |   |
|   |   |   - N=8 Window, K=5 Pattern        |   |   - Equation: (2*R + bit_in) % 3          |   |   |
|   |   |   - Dual-Endian Parallel Slices    |   |   - 3 Remainder States (S0, S1, S2)       |   |   |
|   |   |   - Preamble Burst Lock: 5'b10110  |   |   - Zero-Buffer Physical Error Detection  |   |   |
|   |   +------------------------------------+   +-------------------------------------------+   |   |
|   +----------------------------------------------+---------------------------------------------+   |
+--------------------------------------------------|-------------------------------------------------+
                                                   | Pre-Sanitized Validated Event Telemetry
                                                   v
+----------------------------------------------------------------------------------------------------+
|                            APPLICATION-LAYER SOFTWARE PROCESSING ENGINE                            |
|                                                                                                    |
|   +--------------------------------------------------------------------------------------------+   |
|   | TIER 3: SLIDING-WINDOW SPIKE ENTROPY & NONCE INTEGRITY                                     |   |
|   |   - O(N) Single-Pass ASCII Direct-Mapped Hash Array Deduplication                          |   |
|   |   - 1-Based Indexing with Anti-Rollback Left Window Boundary Protection                    |   |
|   |   - Bidirectional Reflectional Nonce Verification via Center-Expansion Symmetry Check     |   |
|   +----------------------------------------------+---------------------------------------------+   |
|                                                  | Clean De-duplicated Event Frames                |
|                                                  v                                                 |
|   +--------------------------------------------------------------------------------------------+   |
|   | TIER 4: DISTRIBUTED DUAL-STREAM LOGARITHMIC ORDER-STATISTIC THRESHOLDING                   |   |
|   |   - Binary Search Partition on Local Edge Noise vs. Cloud Baseline Buffers                 |   |
|   |   - Formula: j = (m + n + 1) / 2 - i                                                       |   |
|   |   - Time Complexity: O(log(min(m, n))) (<= 10 iterations for 2,000 data points)            |   |
|   |   - Real-Time Dynamic Tuning of LIF Neuron Firing Threshold (V_th)                         |   |
|   +--------------------------------------------------------------------------------------------+   |
+----------------------------------------------------------------------------------------------------+
```

---

## 2. Technical Deep Dive: The 7 Synthesized Pillars

### Pillar 1: Asynchronous CDC Glitch-Rejection Filter
External asynchronous spikes arriving from the ESP8266 over a PCB jumper wire are subject to clock domain crossing metastability when sampled by the FPGA's 100 MHz clock domain ($T_{\text{clk}} = 10\text{ ns}$).
- **2-Flip-Flop Metastability Shield:** Guarantees an exponential increase in Mean Time Between Failures (MTBF):
  $$\text{MTBF} = \frac{e^{t_{\text{resolve}} / \tau_{\text{meta}}}}{T_0 \cdot f_{\text{sys}} \cdot f_{\text{data}}}$$
- **2-Sample Consecutive Filter:** Incoming logic levels must remain stable for two consecutive 100 MHz clock cycles ($\ge 20\text{ ns}$) before transitioning `debounced_level`. High-frequency transmission line ringing and glitches ($< 10\text{ ns}$) are mathematically suppressed.
- **Edge Pulse Derivation:** A single-clock active-high strobe (`ext_spike_pulse = debounced_level & ~debounced_d`) triggers downstream logic for exactly one cycle.

### Pillar 2: Line-Rate Modulo-3 Residue Invariant Engine
To verify incoming serial bitstreams without buffer latency, the FPGA computes residue arithmetic on-the-fly:
$$R_{t+1} \equiv (2 \cdot R_t + b) \pmod 3$$
Implemented as a 3-state Finite State Machine ($S_0, S_1, S_2$) with combinational lookahead logic. If the accumulated bitstream represents a multiple of 3, the state returns to $S_0$ (`div_by_3 = 1`). This provides line-rate, zero-overhead physical integrity verification at 100 Mbps.

### Pillar 3: Dual-Endian Sliding-Window Receptive Field Burst Matcher
To detect structured neuromorphic spike bursts (e.g., synchronous 5-spike burst `5'b10110`), an 8-bit sliding window register evaluates four contiguous 5-bit slices in parallel.
- **Dual-Endian Invariant:** To prevent endianness inversion attacks, slices are evaluated simultaneously against both `5'b10110` (MSB-first) and `5'b01101` (LSB-first):
  $$\text{Match} = \bigvee_{i=0}^{3} \left( W[i+4:i] == 5'\text{b}10110 \lor W[i+4:i] == 5'\text{b}01101 \right)$$
- Matching asserts `pat_found`, triggering a synaptic boost (+500 mV) in the downstream neuron.

### Pillar 4: Digital Leaky Integrate-and-Fire (LIF) Neuromorphic Neuron
The FPGA integrates a hardware Leaky Integrate-and-Fire neuron modeled as:
$$V_{\text{mem}}[t+1] = V_{\text{mem}}[t] - \left(V_{\text{mem}}[t] \gg \text{LEAK}\right) + W_{\text{syn}} \cdot \text{Spike} - V_{\text{th}} \cdot \text{Fire}$$
- **Power-of-Two Leakage:** Shift-based passive membrane leakage (`Vmem >> 2`, decaying 25% of charge every 100 µs) avoids hardware multipliers.
- **Synaptic Plasticity:** Standard spikes add +250 mV; receptive field burst matches add +500 mV.
- **Action Potential:** When $V_{\text{mem}} \ge 1000\text{ mV}$, the neuron asserts `neuron_fire`, hyperpolarizes back to 0 mV, and triggers physical output pin `PMOD JA3`.

### Pillar 5: Silicon-Level Built-In Self-Test (BIST) Engine
For mission-critical reliability, the core includes an on-chip autonomous BIST subsystem:
- **16-Bit Galois LFSR:** Generates a maximal-length pseudo-random binary sequence ($2^{16} - 1 = 65,535$ states) with characteristic polynomial:
  $$P(x) = x^{16} + x^{14} + x^{13} + x^{11} + 1$$
- **16-Bit Multiple-Input Signature Register (MISR):** Compresses internal circuit states (`{pat_found, div_by_3, neuron_fire, rem_state}`) into a signature register.
- **Diagnostics:** When `SW0` is flipped UP, the BIST engine runs 64 pseudo-random test cycles, verifies signature correctness, and asserts `bist_pass` on `PMOD JA4` and `LD2`.

### Pillar 6: $\mathcal{O}(N)$ Sliding-Window Token Deduplication & Entropy
At the software layer, incoming telemetry strings are evaluated for maximum unique token entropy:
- A direct-mapped array `last_seen[256]` of integers provides instantaneous $\mathcal{O}(1)$ addressing.
- **1-Based Indexing:** Storing `right + 1` allows zero-initialization (`{0}`) without loops.
- **Anti-Rollback Guard:** `left = max(left, last_seen[c])` ensures the left window edge never moves backward on duplicate characters (defeating the classic `"abba"` pitfall).

### Pillar 7: Bidirectional Reflectional Symmetry (Palindromic Nonces)
Challenge-response security nonces are validated by testing for reflectional symmetry:
- Evaluates all $2N - 1$ centers (both odd-length $(i, i)$ and even-length $(i, i+1)$) in $\mathcal{O}(N^2)$ time with $\mathcal{O}(1)$ auxiliary space ($< 0.6\text{ ms}$ for $N = 1000$).

### Pillar 8: $\mathcal{O}(\log(\min(m, n)))$ Distributed Logarithmic Order-Statistic Median Filter
When synchronizing dynamic threshold vectors between local edge noise buffers ($m$) and remote cloud baselines ($n$):
- Partitions the smaller array $A$ ($m \le n$) at cut $i \in [0, m]$, deriving cut $j$ as:
  $$j = \left\lfloor \frac{m + n + 1}{2} \right\rfloor - i$$
- Validates the partition in at most $\lceil\log_2(m + 1)\rceil$ steps ($\le 10$ iterations for 2,000 samples), dynamically tuning the LIF neuron's firing threshold $V_{\text{th}}$ in real-time.

---

## 3. Physical Hardware Pinout & Interconnect

### Arduino / ChipKit Header (Bank 14 - 3.3V LVCMOS) to ESP8266

The Arty S7-25 features standard Arduino-compatible female headers on top of the board (Headers J1 & J2). These sockets are clearly silkscreened with `IO0` through `IO13`, `GND`, and `3V3`, allowing direct jumper wire connections from the ESP8266 without requiring right-angle PMOD cables:

| ESP8266 Pin | Arty S7 PCB Header Label | FPGA Pin | Signal Name | Function in Architecture |
| :--- | :--- | :--- | :--- | :--- |
| **GPIO2 (D4 / TXD1)** | **IO2 (Header J1)** | **Pin L16** | `esp_spike_in` | Asynchronous spike bitstream from ESP8266 |
| **GPIO4 (D2)** | **IO3 (Header J1)** | **Pin R14** | `esp_pat_ack` | Hardware burst pattern matched ACK |
| **GPIO5 (D1)** | **IO4 (Header J1)** | **Pin T14** | `esp_neuron_fire`| Digital LIF action potential firing pulse |
| **GPIO12 (D6)** | **IO5 (Header J1)** | **Pin R16** | `esp_bist_pass` | Hardware BIST diagnostic pass status |
| **GND** | **GND (Header J2 or J3)**| **GND** | `GND` | Common Ground Plane Reference |
| **3.3V (VCC)** | **3V3 (Power Header J3)**| **3V3** | `VCC` | 3.3V Regulated Power Rail Reference |

### On-Board Spartan-7 Controls & Visual LED Telemetry

| Hardware Component | Pin | Function / Color | Indication |
| :--- | :--- | :--- | :--- |
| **CLK100MHZ** | **R2** | Bank 34 (SSTL135) | 100 MHz Master System Clock (`INTERNAL_VREF 0.675V`) |
| **RESET_N** | **C18** | Dedicated Red Button | Active-Low Master Reset |
| **SW0** | **H14** | Slide Switch 0 | `DOWN`: Wireless Ingestion Mode \| `UP`: BIST Hardware Self-Test Mode |
| **SW1** | **H18** | Slide Switch 1 | Manual Spike Injection Level |
| **BTN0** | **G15** | Push Button 0 | Manual Spike Clock Step (debounced 10 ms) |
| **BTN1** | **K16** | Push Button 1 | Re-seed / Clear BIST Engine |
| **RGB LED LD0** | **J15/G17/F15** | 🟢 **GREEN** / 🔴 **RED** | 🟢 Residue Invariant Valid (`div_by_3 == 1`) \| 🔴 Residue Error |
| **RGB LED LD1** | **E15/F18/E14** | 🔵 **BLUE** / 🟣 **PURPLE**| 🔵 LIF Neuron Fired (Action Potential) \| 🟣 BIST Active |
| **LED LD2** | **E18** | Green LED | Solid ON on BIST Pass / Residue Valid |
| **LED LD3 & LD4** | **F13 / E13** | Green LEDs | 2-bit binary display of Remainder State ($S_0, S_1, S_2$) |
| **LED LD5** | **H15** | Green LED | Real-time spike activity flash |

---

## 4. Verification & Benchmarking Suite

### A. SystemVerilog Simulation (`tb_neuromorphic_bist.sv`)
Simulated with AMD Vivado 2025.2 `xsim`:
- **Test 1 (Reset):** Remainder starts at 0, `div_by_3 = 1`, membrane potential starts at 0 mV. **[PASS]**
- **Test 2 (Glitch Rejection):** Short $< 10\text{ ns}$ glitch rejected by 2-cycle filter. **[PASS]**
- **Test 3 (CDC Ingestion):** 30 ns stable pulse cleanly accepted and converted to 1-cycle strobe. **[PASS]**
- **Test 4 (Residue Transitions):** Modulo-3 FSM transitions verified at 100 MHz. **[PASS]**
- **Test 5 (LIF Neuron Charging):** Integrated spikes from 0 $\to$ 500 mV $\to$ 750 mV $\to$ 1000 mV (action potential firing and hyperpolarization back to resting potential). **[PASS]**
- **Test 6 (Silicon BIST):** 16-bit LFSR pseudo-random generator and MISR signature compressor completed 64 cycles with valid signature. **[PASS]**

### B. Software Engine (`neuromorphic_software_engine.cpp`)
Compiled with MinGW-w64 G++ (`-O3`):
- **Test 1 (Entropy Deduplication):** $\mathcal{O}(N)$ single-pass deduplication with zero false duplicates. **[PASS]**
- **Test 2 (Reflectional Symmetry):** Correctly detected bidirectional reflectional nonce echo `"_radar_"`. **[PASS]**
- **Test 3 (Logarithmic Median):** Partitioned edge (5) and cloud (6) telemetry buffers to compute adaptive cutoff $980.00\text{ mV}$ in $\le 3$ iterations ($0.000\text{ ms}$). **[PASS]**

### C. Live FPGA Hardware Implementation
- **Target Part:** AMD Xilinx Spartan-7 `xc7s25csga324-1`
- **Synthesis & P&R:** Completed with **0 Errors, 0 Warnings**
- **Timing Closure:** **Worst Negative Slack (WNS) = +4.976 ns** (met with generous margin at 100 MHz)
- **Bitstream:** `neurobist_edge.bit` generated and flashed via JTAG to device `xc7s25_0`

---

## 5. File Inventory & Repository Structure

```
Summarise_Work/
├── index.html                       # Real-Time Interactive Digital Twin & Supervised AI/ML Dashboard
├── twin_bridge.py                   # Python PySerial + WebSocket (ws://:8765) + HTTP Bridge Server
├── run_dashboard.bat                # Double-click script to launch Digital Twin & Bridge server
├── arty_s7_neuromorphic_top.v       # Top-level FPGA module with Arduino IO2..IO5 & LED drivers
├── neuromorphic_bist_core.v         # Core synthesizable RTL (CDC, BIST, LIF, Residue, Matcher)
├── ArtyS7_Master.xdc                # Master physical constraints for Spartan-7 XC7S25
├── esp8266_neuromorphic_synch.ino   # ESP8266 C++ Arduino firmware for wireless synchronization
├── neuromorphic_software_engine.cpp # C++ host intelligence engine (Entropy, Nonces, Median)
├── tb_neuromorphic_bist.sv          # Self-checking SystemVerilog testbench
├── build_and_program.tcl            # Vivado TCL batch synthesis & JTAG flash script
├── program_fpga.bat                 # Double-click script to synthesize and flash FPGA
├── run_simulation.bat               # Double-click script to run Vivado simulation
├── build_and_run_software.bat       # Double-click script to compile and run C++ software
└── README.md                        # Master repository documentation (this file)
```

---

## 6. Quickstart: How to Replicate & Deploy

### Step 1: Launch the Real-Time Digital Twin & Supervised AI Dashboard
Double-click [`run_dashboard.bat`](file:///C:/Users/IITBHU%20RESEARCH%20LAB/OneDrive/Desktop/Arunjyoti_Sarma/My_Coding_files/Day_1/Summarise_Work/run_dashboard.bat) or open [`index.html`](file:///C:/Users/IITBHU%20RESEARCH%20LAB/OneDrive/Desktop/Arunjyoti_Sarma/My_Coding_files/Day_1/Summarise_Work/index.html) in your browser:
* **Direct WebSerial Mode:** Click **"Connect WebSerial"** to connect directly to the ESP8266 (`COM7`) or Arty S7 (`COM5`) without background drivers.
* **WebSocket Bridge Mode:** Launch `python twin_bridge.py` and click **"WS Bridge"** to stream live telemetry via `ws://localhost:8765`.
* **Hardware Digital Twin Sim Mode:** If offline or serial is locked by Arduino IDE, the dashboard runs a cycle-accurate, multi-clock emulation of the Spartan-7 RTL logic with interactive SVG board controls.

### Step 2: Program the Spartan-7 FPGA
Double-click [`program_fpga.bat`](file:///C:/Users/IITBHU%20RESEARCH%20LAB/OneDrive/Desktop/Arunjyoti_Sarma/My_Coding_files/Day_1/Summarise_Work/program_fpga.bat) or run:
```powershell
vivado -mode batch -source build_and_program.tcl -nojournal -nolog
```

### Step 3: Flash the ESP8266
Open [`esp8266_neuromorphic_synch.ino`](file:///C:/Users/IITBHU%20RESEARCH%20LAB/OneDrive/Desktop/Arunjyoti_Sarma/My_Coding_files/Day_1/Summarise_Work/esp8266_neuromorphic_synch.ino) in the Arduino IDE, connect the ESP8266 via USB, select **NodeMCU 1.0 (ESP-12E Module)**, and click **Upload**.

### Step 4: Run the Hardware Simulation
Double-click [`run_simulation.bat`](file:///C:/Users/IITBHU%20RESEARCH%20LAB/OneDrive/Desktop/Arunjyoti_Sarma/My_Coding_files/Day_1/Summarise_Work/run_simulation.bat):
```powershell
xvlog -sv neuromorphic_bist_core.v tb_neuromorphic_bist.sv
xelab -top tb_neuromorphic_bist -snapshot sim_neuro_snap -debug typical
xsim sim_neuro_snap -runall
```

### Step 5: Run the Host Software Intelligence Suite
Double-click [`build_and_run_software.bat`](file:///C:/Users/IITBHU%20RESEARCH%20LAB/OneDrive/Desktop/Arunjyoti_Sarma/My_Coding_files/Day_1/Summarise_Work/build_and_run_software.bat) or run:
```powershell
g++ -static -O3 neuromorphic_software_engine.cpp -o neuromorphic_software_engine.exe
.\neuromorphic_software_engine.exe
```

---

## 7. Citation & Academic Attribution

If you utilize this hardware-software co-processor, synthesizable Verilog RTL, or Digital Twin architecture in your research, academic publications, or student projects, please cite this repository:

```bibtex
@misc{sarma2026neurobist,
  author = {Sarma, Arunjyoti},
  title = {NeuroBIST-Edge: Autonomous Fault-Tolerant Neuromorphic Co-Processor with Silicon BIST and Mod-3 Residue Self-Healing across AMD Spartan-7 FPGA and ESP8266},
  year = {2026},
  month = {September},
  publisher = {GitHub},
  journal = {GitHub repository},
  howpublished = {\url{https://github.com/arunjyotisarmarsece24-jpg/NeuroBIST-Edge}},
  institution = {Indian Institute of Technology (BHU)}
}
```

### License & Acknowledgments
- **License:** Released under the permissive [MIT License](LICENSE) for research, academic, and non-commercial development.
- **Affiliation:** Indian Institute of Technology (BHU), Department of Electronics Engineering.
- **Hardware Ecosystem:** Digilent Arty S7-25 (AMD Spartan-7 FPGA) & Espressif Systems (NodeMCU ESP8266).
