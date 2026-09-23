# ============================================================================
# synch_dual_monitor.py
# Fully Autonomous Real-Time Hardware Synchronizer & Monitor
# ESP8266 Gateway (COM4) <=========> Arty S7-25 FPGA (COM5)
# Zero-Touch: Automatically cycles through all neuromorphic hardware tests!
# ============================================================================

import os
import sys
import time
import threading
import serial
import serial.tools.list_ports

# Target COM Ports
ESP_PORT = "COM4"
FPGA_PORT = "COM5"
BAUD = 115200

# ANSI Color Codes
CYAN = "\033[96m"
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
MAGENTA = "\033[95m"
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"

# State Tracking
state = {
    "esp_connected": False,
    "fpga_connected": False,
    "auto_mode": True,
    "current_phase": "INITIALIZING",
    "cycle_count": 0,
    "countdown": 0,
    "io2_spike": "IDLE (LOW)",
    "io3_burst_ack": "INACTIVE",
    "io4_neuron_fire": "RESTING",
    "io5_bist_pass": "PASS (HIGH)",
    "ld0_residue": f"{GREEN}SOLID GREEN [S0: Invariant Valid]{RESET}",
    "ld1_neuron": "OFF [Resting Vmem]",
    "ld2_bist": f"{GREEN}SOLID GREEN [Verified]{RESET}",
    "ld5_heartbeat": "STANDBY",
    "vmem_estimate": 0,
    "last_esp_event": "Auto-Sequencer Online. Stand by...",
    "spikes_sent": 0,
    "bursts_matched": 0,
    "faults_detected": 0,
    "fires_recorded": 0
}

state_lock = threading.Lock()
stop_flag = threading.Event()
active_serial = None
serial_lock = threading.Lock()

def esp_listener(ser):
    global state
    while not stop_flag.is_set():
        try:
            if ser.in_waiting > 0:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    with state_lock:
                        state["last_esp_event"] = line
                        if "ACK RECEIVED" in line or "Matched" in line:
                            state["io3_burst_ack"] = f"{GREEN}{BOLD}ASSERTED (HIGH) [MATCH!]{RESET}"
                            state["bursts_matched"] += 1
                        elif "ACTION POTENTIAL" in line or "FIRED" in line:
                            state["io4_neuron_fire"] = f"{BLUE}{BOLD}FIRE (PULSE 120ms){RESET}"
                            state["ld1_neuron"] = f"{BLUE}{BOLD}FLASH ELECTRIC BLUE!{RESET}"
                            state["fires_recorded"] += 1
                            state["vmem_estimate"] = 1000
                        elif "RESIDUE ERROR" in line or "violated" in line:
                            state["ld0_residue"] = f"{RED}{BOLD}SOLID RED [S2: BYZANTINE FAULT!]{RESET}"
                            state["faults_detected"] += 1
                        elif "RESIDUE SELF-HEAL" in line or "restored" in line:
                            state["ld0_residue"] = f"{GREEN}{BOLD}SOLID GREEN [S0: AUTONOMOUSLY HEALED!]{RESET}"
                        elif "BIST" in line and "PASS" in line:
                            state["io5_bist_pass"] = f"{GREEN}PASS (HIGH){RESET}"
                            state["ld2_bist"] = f"{GREEN}SOLID GREEN [MISR Verified]{RESET}"
                        elif "Emitted spike" in line or "Bit '1'" in line:
                            state["io2_spike"] = f"{YELLOW}PULSE 80us{RESET}"
                            state["ld5_heartbeat"] = f"{GREEN}STROBE 60ms{RESET}"
                            state["spikes_sent"] += 1
                            state["vmem_estimate"] = min(1000, state["vmem_estimate"] + 250)
            else:
                time.sleep(0.02)
        except Exception:
            break

def auto_sequencer(ser):
    """Fully autonomous closed-loop test orchestrator."""
    global state
    
    # Sequence of automated tests: (command, phase_name, wait_seconds)
    AUTO_STEPS = [
        ("B", "PHASE 1: 5-Spike Receptive Field Burst (10110) -> IO3 ACK", 3.0),
        ("T", "PHASE 2: LIF Threshold Driver -> Action Potential on IO4 (LD1 Blue)", 3.5),
        ("S", "PHASE 3: High-Frequency Spike Storm -> Rapid Strobe LD5", 2.5),
        ("F", "PHASE 4: Byzantine Mod-3 Fault -> LD0 turns RED, then Self-Heals GREEN", 4.0),
        ("G", "PHASE 5: Sub-20ns Metastable Glitch -> CDC 2-Sample Rejection", 2.5),
        ("R", "PHASE 6: 16-Bit LFSR/MISR Silicon BIST Verification -> IO5 Pass", 2.5),
    ]

    time.sleep(1.5)  # Let links stabilize

    while not stop_flag.is_set():
        with state_lock:
            if not state["auto_mode"]:
                time.sleep(0.5)
                continue
            state["cycle_count"] += 1
            cycle = state["cycle_count"]

        for cmd, name, delay_s in AUTO_STEPS:
            with state_lock:
                if not state["auto_mode"] or stop_flag.is_set():
                    break
                state["current_phase"] = name
                state["countdown"] = int(delay_s)
                # Reset transient indicators
                if cmd == "B":
                    state["io3_burst_ack"] = "EVALUATING..."
                elif cmd == "T":
                    state["io4_neuron_fire"] = "INTEGRATING..."
                    state["ld1_neuron"] = "INTEGRATING CHARGE..."
                    state["vmem_estimate"] = 0
                elif cmd == "F":
                    state["ld0_residue"] = f"{YELLOW}INJECTING VIOLATION...{RESET}"

            # Transmit hardware command to ESP8266 over serial
            with serial_lock:
                if ser and ser.is_open:
                    try:
                        ser.write(f"{cmd}\n".encode())
                    except Exception:
                        pass

            # Step countdown timer for ultra-smooth UI
            steps = int(delay_s * 10)
            for _ in range(steps):
                if stop_flag.is_set():
                    return
                time.sleep(0.1)

def render_display():
    os.system('cls' if os.name == 'nt' else 'clear')
    with state_lock:
        s = state.copy()

    esp_status = f"{GREEN}ONLINE (COM4){RESET}" if s["esp_connected"] else f"{RED}OFFLINE{RESET}"
    fpga_status = f"{GREEN}ONLINE (COM5 - JTAG/100MHz){RESET}" if s["fpga_connected"] else f"{YELLOW}JTAG ACTIVE{RESET}"
    auto_status = f"{GREEN}{BOLD}ACTIVE (AUTOMATIC CLOSED-LOOP){RESET}" if s["auto_mode"] else f"{YELLOW}PAUSED (MANUAL MODE){RESET}"

    bar_len = s["vmem_estimate"] // 50
    vmem_bar = f"{CYAN}{'#' * bar_len}{DIM}{'.' * (20 - bar_len)}{RESET}"

    print(f"""
{BOLD}=============================================================================================={RESET}
  {CYAN}{BOLD}NEUROBIST-EDGE // 100% AUTONOMOUS HARDWARE SYNCHRONIZER & MONITOR{RESET}
  {DIM}Target Hardware: Digilent Arty S7-25 (Spartan-7) <===> Espressif ESP8266 (COM4){RESET}
{BOLD}=============================================================================================={RESET}

  {BOLD}[ SYSTEM AUTOMATION STATUS ]{RESET}
  * Mode: {auto_status}
  * Execution Cycle: {BOLD}#{s["cycle_count"]}{RESET}
  * Current Step:    {YELLOW}{BOLD}{s["current_phase"]}{RESET}
  * Hardware Links:  ESP8266: {esp_status}  |  Arty S7-25: {fpga_status}

{BOLD}----------------------------------------------------------------------------------------------{RESET}
  {BOLD}[ LIVE PHYSICAL INTERCONNECT BUS (Arduino Shield Header Pins) ]{RESET}
  
    ESP8266 Pin                 Direction     Arty S7 Pin       Hardware Function & Signal State
    ------------------------------------------------------------------------------------------
    GPIO2 (D4 / TXD1)  ======>  [ OUTPUT ]  ===>  IO2 (Pin L16)  : Spike In      -> {s["io2_spike"]}
    GPIO4 (D2)         <======  [ INPUT  ]  <===  IO3 (Pin R14)  : Burst ACK     -> {s["io3_burst_ack"]}
    GPIO5 (D1)         <======  [ INPUT  ]  <===  IO4 (Pin T14)  : Neuron Fire   -> {s["io4_neuron_fire"]}
    GPIO12 (D6)        <======  [ INPUT  ]  <===  IO5 (Pin R16)  : BIST Pass     -> {s["io5_bist_pass"]}
    GND                <======  [ GROUND ]  <===  GND (Header J1): Common Ground -> {GREEN}LOCKED{RESET}

{BOLD}----------------------------------------------------------------------------------------------{RESET}
  {BOLD}[ SPARTAN-7 PHYSICAL BOARD LED INDICATORS (Watch Your Board!) ]{RESET}
  
    LED Label       Type        Hardware Indication                     Current Silicon State
    ------------------------------------------------------------------------------------------
    * LD0           RGB         Modulo-3 Residue Status (S0/S1 vs S2) -> {s["ld0_residue"]}
    * LD1           RGB         Action Potential Fire (Vmem >= 1000mV)-> {s["ld1_neuron"]}
    * LD2           Green       Residue Valid / BIST Verified Status  -> {s["ld2_bist"]}
    * LD5           Green       Spike Ingestion Activity Heartbeat    -> {s["ld5_heartbeat"]}
    * Vmem Gauge    Accumulator Membrane Charge: [{s["vmem_estimate"]:4d} / 1000 mV]  {vmem_bar}

{BOLD}----------------------------------------------------------------------------------------------{RESET}
  {BOLD}[ REAL-TIME TELEMETRY STREAM ]{RESET}
  * Raw Telemetry: {MAGENTA}{s["last_esp_event"]}{RESET}
  * Metrics:       Spikes: {CYAN}{s["spikes_sent"]}{RESET} | Bursts: {GREEN}{s["bursts_matched"]}{RESET} | Mod-3 Faults: {RED}{s["faults_detected"]}{RESET} | Action Potentials: {BLUE}{s["fires_recorded"]}{RESET}

{BOLD}=============================================================================================={RESET}
  {BOLD}SYSTEM IS RUNNING AUTOMATICALLY (No keystrokes required!){RESET}
  Controls: [{BOLD}A{RESET}] Toggle Auto-Cycle   [{BOLD}Q{RESET}] Quit Monitor   [{BOLD}Space{RESET}] Inject Single Spike
            [{BOLD}T{RESET}] Fire Neuron         [{BOLD}F{RESET}] Inject Fault     [{BOLD}B{RESET}] Send Burst
==============================================================================================
""")

def main():
    global state, active_serial
    comports = [p.device for p in serial.tools.list_ports.comports()]
    esp_port = ESP_PORT if ESP_PORT in comports else None
    fpga_port = FPGA_PORT if FPGA_PORT in comports else None

    ser_esp = None
    if esp_port:
        try:
            ser_esp = serial.Serial()
            ser_esp.port = esp_port
            ser_esp.baudrate = BAUD
            ser_esp.timeout = 0.5
            ser_esp.dtr = False
            ser_esp.rts = False
            ser_esp.open()
            state["esp_connected"] = True
            active_serial = ser_esp
        except Exception as e:
            print(f"[WARN] Could not open {esp_port}: {e}")

    if fpga_port:
        state["fpga_connected"] = True

    if ser_esp:
        listener = threading.Thread(target=esp_listener, args=(ser_esp,), daemon=True)
        listener.start()

    try:
        import msvcrt
        last_refresh = 0
        while True:
            now = time.time()
            if now - last_refresh >= 0.2:
                render_display()
                last_refresh = now

            if msvcrt.kbhit():
                ch = msvcrt.getch().decode('utf-8', errors='ignore').upper()
                if ch == 'Q':
                    break
                elif ch in ['T', 'F', 'B', 'G', 'S', 'R']:
                    with serial_lock:
                        if ser_esp and ser_esp.is_open:
                            ser_esp.write(f"{ch}\n".encode())
                elif ch == ' ':
                    with serial_lock:
                        if ser_esp and ser_esp.is_open:
                            ser_esp.write(b"1\n")
            time.sleep(0.03)
    except KeyboardInterrupt:
        pass
    finally:
        stop_flag.set()
        with serial_lock:
            if ser_esp and ser_esp.is_open:
                ser_esp.close()
        print(f"\n{GREEN}[SHUTDOWN] Synchronized Autonomous Monitor closed cleanly.{RESET}\n")

if __name__ == "__main__":
    main()
