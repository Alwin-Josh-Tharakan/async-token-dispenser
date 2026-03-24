# Asynchronous Smart Token Dispenser 🪙

This repository contains the RTL design, testbench, and simulation results for a **Fundamental-Mode Asynchronous Sequential Circuit (ASC)**. The system acts as a smart token dispenser controller designed entirely without a global clock signal, responding instantly to physical input events.

## 🚀 Key Features

* **Zero Clock Latency:** Operates strictly in fundamental mode. State transitions are event-driven, minimizing dynamic power consumption.
* **Essential Hazard Mitigation:** Uses a custom "Hold and Wait" alternating state architecture to prevent double-counting of physical token pulses (sensor lingering).
* **Race-Free State Assignment:** Implements a Gray-code-like state assignment strategy ensuring only a single bit changes during any state transition, completely eliminating critical races.
* **Logic Synthesis Ready:** Behavioral FSM modeling that synthesizes perfectly into unclocked combinational logic and feedback loops.

## ⚙️ System Specifications

* **Target Release Threshold:** 15 Units
* **Accepted Inputs:** 5-Unit (`In5`) and 10-Unit (`In10`) Tokens
* **Outputs:** * `Token_Release`: Triggers when the 15-unit threshold is met.
    * `Coin_Return`: Triggers to refund 5 units if 20 units are inserted.

## 🛠️ Tools Used
* **Simulation:** Icarus Verilog (iVerilog)
* **Waveform Viewer:** GTKWave
* **Synthesis & RTL Schematic:** Xilinx Vivado

## 📂 Repository Structure
* `rtl/` : Contains the main Verilog hardware description (`TokenDispenser_ASC.v`).
* `tb/` : Contains the Verilog testbench covering 8 distinct edge-case scenarios (`TokenDispenser_tb.v`).
* `docs/` : Contains the RTL schematic and the reduced flow table analysis.

## 💻 How to Run the Simulation

If you have Icarus Verilog and GTKWave installed, you can run the testbench directly from your terminal:

1. Compile the code:
   ```bash
   iverilog -o token_sim rtl/TokenDispenser_ASC.v tb/TokenDispenser_tb.v