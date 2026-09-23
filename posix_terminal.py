# ============================================================================
# POSIX Silicon Terminal (term0) for Neuromorphic Hardware
# Inspired by Machdyne Zeitlos & Open-Source Silicon Workstations
# Hardware: Digilent Arty S7-25 (COM5/JTAG) <==> ESP8266 Gateway (COM4)
# ============================================================================

import sys
import time
import threading
import serial
import serial.tools.list_ports

PORT = "COM4"
BAUD = 115200

BANNER = r"""
+-------------------------------------------------------------------------+
|  term0 -- Open-Source POSIX Silicon Shell for Neuromorphic Edge-OS      |
|  Target: Digilent Arty S7-25 (Spartan-7) <==> Espressif ESP8266 Gateway  |
|  Type 'help' for command list | 'exit' to quit                          |
+-------------------------------------------------------------------------+
"""

HELP_TEXT = """
Built-in Commands:
  help                     Show this command manual
  status                   Query active hardware links and COM ports
  fire                     Drive LIF neuron to firing threshold (Action Potential on IO4)
  fault                    Inject Byzantine Mod-3 desync timing fault (LD0 RED -> GREEN)
  burst                    Send 5-spike receptive field pattern 10110 (ACK on IO3)
  glitch                   Inject sub-20ns metastable runt pulse (CDC filter verification)
  flood                    Stream high-frequency spike flood (LD5 activity strobe)
  bist                     Query 16-bit LFSR / MISR Built-In Self-Test status
  clear                    Clear screen buffer
  exit                     Exit term0 shell
"""

def serial_listener(ser, stop_event):
    while not stop_event.is_set():
        try:
            if ser.in_waiting > 0:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    print(f"\n\033[36m[HW-RECV]\033[0m {line}\nterm0: /dev/arty_s7 $ ", end="", flush=True)
            else:
                time.sleep(0.05)
        except Exception:
            break

def main():
    print(BANNER)
    
    # Check COM ports
    comports = [p.device for p in serial.tools.list_ports.comports()]
    target_port = PORT if PORT in comports else (comports[0] if comports else None)
    
    if not target_port:
        print("\033[31m[ERROR] No COM port detected. Connect ESP8266 / Arty S7 to continue.\033[0m")
        return

    print(f"\033[32m[INIT]\033[0m Hooking serial transceiver into {target_port} @ {BAUD} baud...")
    try:
        ser = serial.Serial()
        ser.port = target_port
        ser.baudrate = BAUD
        ser.timeout = 1
        ser.dtr = False
        ser.rts = False
        ser.open()
        time.sleep(0.3)
        print(f"\033[32m[LINK ONLINE]\033[0m Physical bus locked to {target_port}. Ready for commands.\n")
    except Exception as e:
        print(f"\033[31m[ERROR]\033[0m Unable to open {target_port}: {e}")
        return

    stop_event = threading.Event()
    listener_thread = threading.Thread(target=serial_listener, args=(ser, stop_event), daemon=True)
    listener_thread.start()

    try:
        while True:
            cmd = input("term0: /dev/arty_s7 $ ").strip().lower()
            if not cmd:
                continue
            if cmd == "exit":
                print("[SHUTDOWN] Exiting term0 shell...")
                break
            elif cmd == "help":
                print(HELP_TEXT)
            elif cmd == "clear":
                print("\033[2J\033[H", end="")
                print(BANNER)
            elif cmd == "status":
                print(f"[STATUS] Hardware Transceiver: {target_port} (115200 8N1)")
                print("         FPGA Target: Digilent Arty S7-25 (AMD Spartan-7 XC7S25)")
                print("         Interconnect: IO2(Spike), IO3(ACK), IO4(Fire), IO5(BIST), GND")
            elif cmd == "fire":
                print("\033[35m[DOWNLINK -> IO2]\033[0m Emitting spike train toward V_th (1000 mV)...")
                ser.write(b"T\n")
            elif cmd == "fault":
                print("\033[31m[DOWNLINK -> IO2]\033[0m Emitting Byzantine Mod-3 timing violation...")
                ser.write(b"F\n")
            elif cmd == "burst":
                print("\033[33m[DOWNLINK -> IO2]\033[0m Emitting receptive field burst 5'b10110...")
                ser.write(b"B\n")
            elif cmd == "glitch":
                print("\033[34m[DOWNLINK -> IO2]\033[0m Emitting sub-20ns metastable runt pulse...")
                ser.write(b"G\n")
            elif cmd == "flood":
                print("\033[35m[DOWNLINK -> IO2]\033[0m Emitting high-frequency spike flood...")
                ser.write(b"S\n")
            elif cmd == "bist":
                print("\033[36m[DOWNLINK -> IO5]\033[0m Querying FPGA BIST MISR signature...")
                ser.write(b"R\n")
            else:
                print(f"term0: command not found: {cmd}. Type 'help' for builtins.")
            time.sleep(0.2)
    except KeyboardInterrupt:
        print("\n[SIGINT] Interrupted by user.")
    finally:
        stop_event.set()
        ser.close()
        print("[LINK TERMINATED] Bus released safely.")

if __name__ == "__main__":
    main()
