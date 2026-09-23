# ============================================================================
# Script: twin_bridge.py
# Role: Real-Time Hardware Bridge Server for NeuroBIST-Edge Digital Twin
# Features:
#   1. Scans and connects to ESP8266 (COM4) and Arty S7 (COM5) via PySerial.
#   2. Full Bidirectional Hardware Downlink: forwards WebSocket commands to hardware.
#   3. Runs an asynchronous WebSocket server on ws://localhost:8765 to broadcast telemetry.
#   4. Runs a lightweight HTTP server on http://localhost:8000 serving index.html.
#   5. Gracefully handles port contention (e.g. WebSerial, Arduino IDE Serial Monitor).
# ============================================================================

import asyncio
import http.server
import json
import os
import socketserver
import sys
import threading
import time
import webbrowser
import serial
import serial.tools.list_ports

if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(line_buffering=True)
        sys.stderr.reconfigure(line_buffering=True)
    except Exception:
        pass

HTTP_PORT = 8000
WS_PORT = 8765
CONNECTED_CLIENTS = set()
TARGET_SERIAL_PORTS = ['COM4', 'COM7', 'COM5']
SERIAL_BAUD = 115200

# Global shared state
shared_state = {
    "connected_port": None,
    "last_message": "Bridge initialized",
    "spikes_count": 0,
    "fires_count": 0,
    "bist_pass": False,
    "active_clients": 0
}

# Global serial connection reference for bidirectional downlink
active_serial = None
serial_lock = threading.Lock()

def send_serial_command(cmd_str):
    """Writes a command string to the active hardware serial port."""
    global active_serial
    with serial_lock:
        if active_serial and active_serial.is_open:
            try:
                msg = cmd_str.strip() + "\n"
                active_serial.write(msg.encode('utf-8'))
                active_serial.flush()
                print(f"\033[35m[DOWNLINK -> {shared_state['connected_port']}]\033[0m Sent: '{cmd_str.strip()}'")
                return True
            except Exception as e:
                print(f"[DOWNLINK ERROR] Failed to send '{cmd_str.strip()}': {e}")
                return False
        else:
            print(f"[DOWNLINK WARN] Hardware not connected. Command '{cmd_str.strip()}' dropped.")
            return False

class QuietHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        # Suppress routine GET logs for clean console
        pass

def run_http_server():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    socketserver.TCPServer.allow_reuse_address = True
    try:
        with socketserver.TCPServer(("", HTTP_PORT), QuietHTTPRequestHandler) as httpd:
            print(f"[HTTP SERVER] Serving Digital Twin dashboard at: http://localhost:{HTTP_PORT}")
            httpd.serve_forever()
    except OSError:
        pass

def is_port_in_use(port):
    import socket
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) == 0

def serial_reader_thread(loop):
    global shared_state, active_serial
    print("[SERIAL] Scanning for active serial interfaces...")
    
    while True:
        comports = serial.tools.list_ports.comports()
        chosen_port = None
        
        # 1. Prioritize ESP8266 / NodeMCU CP210x or CH340 devices
        for p in comports:
            desc = p.description.lower()
            if "cp210" in desc or "ch340" in desc or "nodemcu" in desc:
                chosen_port = p.device
                break

        # 2. Check prioritized target ports
        if not chosen_port:
            port_names = [p.device for p in comports]
            for target in TARGET_SERIAL_PORTS:
                if target in port_names:
                    chosen_port = target
                    break

        # 3. Fall back to non-AMT serial ports
        if not chosen_port and comports:
            valid_ports = [p.device for p in comports if "amt" not in p.description.lower()]
            if valid_ports:
                chosen_port = valid_ports[0]

        if not chosen_port:
            print("[SERIAL] No COM ports detected. Waiting 3 seconds...")
            time.sleep(3)
            continue

        try:
            print(f"[SERIAL] Attempting connection to {chosen_port} at {SERIAL_BAUD} baud...")
            ser = serial.Serial()
            ser.port = chosen_port
            ser.baudrate = SERIAL_BAUD
            ser.timeout = 1
            ser.dtr = False
            ser.rts = False
            ser.open()
            
            with serial_lock:
                active_serial = ser
            
            with ser:
                shared_state["connected_port"] = chosen_port
                print(f"\033[32m[SERIAL CONNECTED] Successfully hooked into {chosen_port}!\033[0m")
                
                # Broadcast connect event to clients
                asyncio.run_coroutine_threadsafe(
                    broadcast_to_clients(json.dumps({
                        "type": "port_status",
                        "status": "connected",
                        "port": chosen_port
                    })), loop
                )
                
                import re
                ansi_cleaner = re.compile(r'\x1b\[[0-9;]*[a-zA-Z]|\u001b\[[0-9;]*[a-zA-Z]|\[[0-9;]+m|\[0m')
                while True:
                    line = ser.readline().decode('utf-8', errors='ignore').strip()
                    if line:
                        clean_line = ansi_cleaner.sub('', line).strip()
                        shared_state["last_message"] = clean_line
                        if "ACTION POTENTIAL" in clean_line or "FIRED" in clean_line:
                            shared_state["fires_count"] += 1
                        elif "Emitting" in clean_line or "Spike" in clean_line or "STORM" in clean_line:
                            shared_state["spikes_count"] += 1
                        elif "BIST" in clean_line and "PASS" in clean_line:
                            shared_state["bist_pass"] = True

                        # Broadcast to websocket clients
                        payload = json.dumps({
                            "type": "telemetry",
                            "port": chosen_port,
                            "raw": clean_line,
                            "spikes": shared_state["spikes_count"],
                            "fires": shared_state["fires_count"],
                            "bist_pass": shared_state["bist_pass"]
                        })
                        asyncio.run_coroutine_threadsafe(broadcast_to_clients(payload), loop)
        except serial.SerialException as se:
            with serial_lock:
                active_serial = None
            shared_state["connected_port"] = None
            
            if "Access is denied" in str(se) or "PermissionError" in str(se):
                print(f"\033[33m[PORT LOCKED] {chosen_port} is open in another application (e.g. Chrome WebSerial tab).\033[0m")
                print("              Disconnect WebSerial in your browser to give exclusive access to Python bridge.")
            else:
                print(f"[SERIAL WARN] Port {chosen_port} error: {se}")
            time.sleep(3)
        except Exception as e:
            with serial_lock:
                active_serial = None
            shared_state["connected_port"] = None
            print(f"[SERIAL ERROR] Unexpected error: {e}")
            time.sleep(3)

async def broadcast_to_clients(message):
    if CONNECTED_CLIENTS:
        for client in list(CONNECTED_CLIENTS):
            try:
                await client.send(message)
            except Exception:
                CONNECTED_CLIENTS.discard(client)

async def ws_handler(websocket):
    CONNECTED_CLIENTS.add(websocket)
    shared_state["active_clients"] = len(CONNECTED_CLIENTS)
    print(f"\033[36m[WS CLIENT CONNECTED]\033[0m Total clients active: {len(CONNECTED_CLIENTS)}")
    
    # Send initial handshake with current connection state
    try:
        await websocket.send(json.dumps({
            "type": "handshake",
            "status": "ready",
            "connected_port": shared_state["connected_port"],
            "info": "NeuroBIST-Edge Bidirectional Hardware Bridge v2.0"
        }))
    except Exception:
        pass

    try:
        async for msg in websocket:
            try:
                data = json.loads(msg)
                cmd = data.get("cmd") or data.get("command")
                if cmd:
                    success = send_serial_command(cmd)
                    await websocket.send(json.dumps({
                        "type": "cmd_ack",
                        "cmd": cmd,
                        "success": success,
                        "port": shared_state["connected_port"]
                    }))
            except json.JSONDecodeError:
                # Raw text string command
                raw_cmd = msg.strip()
                if raw_cmd:
                    success = send_serial_command(raw_cmd)
                    await websocket.send(json.dumps({
                        "type": "cmd_ack",
                        "cmd": raw_cmd,
                        "success": success,
                        "port": shared_state["connected_port"]
                    }))
    except Exception:
        pass
    finally:
        CONNECTED_CLIENTS.discard(websocket)
        shared_state["active_clients"] = len(CONNECTED_CLIENTS)
        print(f"[WS CLIENT DISCONNECTED] Remaining clients: {len(CONNECTED_CLIENTS)}")

async def run_ws_server():
    import websockets
    print(f"[WS SERVER] Starting WebSocket bridge at ws://localhost:{WS_PORT}")
    while True:
        try:
            async with websockets.serve(ws_handler, "localhost", WS_PORT, ping_interval=20, ping_timeout=20):
                await asyncio.Future()  # run forever
        except asyncio.CancelledError:
            break
        except Exception as e:
            print(f"[WS SERVER ERROR] {e}. Rebinding in 2 seconds...")
            await asyncio.sleep(2)

def main():
    print("================================================================")
    print("  NEUROBIST-EDGE // BIDIRECTIONAL DIGITAL TWIN BRIDGE SERVER    ")
    print("================================================================")

    # 0. Check if another bridge server instance is already running
    if is_port_in_use(WS_PORT):
        print("\033[32m[ALREADY RUNNING] NeuroBIST-Edge bridge server is ALREADY ACTIVE!\033[0m")
        print(f"                  HTTP Dashboard:   http://localhost:{HTTP_PORT}")
        print(f"                  WebSocket Bridge: ws://localhost:{WS_PORT}")
        print(f"\n[LAUNCH] Opening dashboard in your browser...")
        try:
            webbrowser.open(f"http://localhost:{HTTP_PORT}")
        except Exception:
            pass
        print("\n[OK] Everything is live! You can close this console window.")
        return

    # 1. Start HTTP Server in background thread
    http_thread = threading.Thread(target=run_http_server, daemon=True)
    http_thread.start()

    # 2. Start WebSocket and Serial reader in main async event loop
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    serial_thread = threading.Thread(target=serial_reader_thread, args=(loop,), daemon=True)
    serial_thread.start()

    # 3. Automatically open dashboard in browser
    time.sleep(1)
    url = f"http://localhost:{HTTP_PORT}"
    print(f"\n[LAUNCH] Opening browser at: {url}\n")
    try:
        webbrowser.open(url)
    except Exception:
        pass

    while True:
        try:
            loop.run_until_complete(run_ws_server())
        except KeyboardInterrupt:
            print("\n[STOP] Shutting down bridge server.")
            sys.exit(0)
        except Exception as e:
            print(f"[SERVER EXCEPTION] {e}. Retrying in 2 seconds...")
            time.sleep(2)

if __name__ == "__main__":
    main()
