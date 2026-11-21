#!/usr/bin/env python3
"""
JODU52140 Reverse Engineering & Management Tool
Automated CLI for inspecting, querying, and managing the Jio 5G Outdoor Unit (JODU52140)
via UART Serial Console (1.8V TTL, 115200 8N1) or direct ADB.
"""

import argparse
import json
import os
import subprocess
import sys
import time

try:
    import serial
except ImportError:
    serial = None


class ODUConsole:
    def __init__(self, port="/dev/ttyUSB0", baudrate=115200, timeout=1.5, use_adb=False):
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.use_adb = use_adb
        self.ser = None

    def connect(self):
        if self.use_adb:
            # Verify adb is active
            res = subprocess.run(["adb", "devices"], capture_output=True, text=True)
            if "device" not in res.stdout:
                sys.exit("Error: No ADB device detected. Use serial or connect USB.")
            return

        if serial is None:
            sys.exit("Error: pyserial is required for serial mode. Install via 'pip install pyserial' or pass --adb")

        try:
            self.ser = serial.Serial(self.port, self.baudrate, timeout=self.timeout)
            self._ensure_login()
        except serial.SerialException as e:
            sys.exit(f"Failed to open serial port {self.port}: {e}")

    def close(self):
        if self.ser and self.ser.is_open:
            self.ser.close()

    def _ensure_login(self, username="root", password="oelinux123"):
        self.ser.write(b"\n")
        time.sleep(0.3)
        buf = self.ser.read(2048).decode("utf-8", errors="replace")
        if "login:" in buf.lower():
            self.ser.write(f"{username}\n".encode())
            time.sleep(0.5)
            self.ser.write(f"{password}\n".encode())
            time.sleep(1.0)
            self.ser.read(2048)
        elif "Password:" in buf:
            self.ser.write(f"{password}\n".encode())
            time.sleep(1.0)
            self.ser.read(2048)

    def run_command(self, cmd, timeout=5.0):
        if self.use_adb:
            res = subprocess.run(["adb", "shell", cmd], capture_output=True, text=True, timeout=timeout)
            return res.stdout.strip()

        self._ensure_login()
        self.ser.write((cmd + "\n").encode("utf-8"))
        time.sleep(0.3)
        resp = ""
        start = time.time()
        while time.time() - start < timeout:
            chunk = self.ser.read(4096).decode("utf-8", errors="replace")
            if chunk:
                resp += chunk
                if "root@sdxlemur:" in resp:
                    break
            else:
                time.sleep(0.1)

        # Clean output
        lines = resp.splitlines()
        cleaned = []
        for l in lines:
            if l.strip() == cmd.strip() or "root@sdxlemur:" in l:
                continue
            cleaned.append(l)
        return "\n".join(cleaned).strip()

    def ubus_call(self, obj, method, params=None):
        if params is None:
            params = {}
        payload = json.dumps(params)
        cmd = f"ubus call {obj} {method} '{payload}'"
        raw = self.run_command(cmd)
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return {"raw": raw}

    def at_cmd(self, command):
        cmd = f"lux_atc '{command}'"
        return self.run_command(cmd)


def mask_mac(mac):
    if not mac or mac == "N/A":
        return mac
    parts = str(mac).split(":")
    if len(parts) == 6:
        return f"{parts[0]}:{parts[1]}:{parts[2]}:XX:XX:XX"
    return mac


def mask_serial(sn):
    if not sn or sn == "N/A":
        return sn
    s = str(sn)
    if len(s) > 8:
        return s[:7] + "X" * (len(s) - 7)
    return s


def mask_eid(eid):
    if not eid or eid == "N/A":
        return eid
    s = str(eid).strip()
    if len(s) > 12:
        return s[:12] + "X" * (len(s) - 12)
    return s


def cmd_info(odu):
    print("\n--- [ Device Hardware & System Metadata ] ---")
    sys_info = odu.ubus_call("luxslam", "sys", {"cmd": "get", "class": "device"})
    if isinstance(sys_info, dict) and "params" in sys_info:
        p = sys_info["params"]
        print(f"Product Name:     {p.get('product_name', 'Jio ODU')}")
        print(f"Device Model:     {p.get('model', 'JODU52140')}")
        print(f"Hardware Version: {p.get('hardware_version', 'N/A')}")
        print(f"ODM:              {p.get('odm', 'LUXSHARE')}")
        print(f"Serial Number:    {mask_serial(p.get('serial_number', 'N/A'))}")
        print(f"Base MAC:         {mask_mac(p.get('mac_address', 'N/A'))}")
        print(f"Software Version: {p.get('software_version', 'N/A')}")
        print(f"Kernel Version:   {p.get('kernel_version', 'N/A')}")
        print(f"System Uptime:    {p.get('system_time', 'N/A')}")
    else:
        print(sys_info)


def cmd_rf(odu):
    print("\n--- [ Real-Time 5G Cellular Metrics ] ---")
    rf_info = odu.ubus_call("luxslam", "5g", {"cmd": "get", "class": "serving_cell"})
    if isinstance(rf_info, dict) and "params" in rf_info:
        p = rf_info["params"]
        print(f"Status:          {p.get('cellular_status', 'N/A')}")
        print(f"5G Band:         {p.get('nr_band', 'n78')} ({p.get('nr_bandwidth', '100 MHz')})")
        print(f"PLMN:            {p.get('nr_plmn', '405862')}")
        print(f"NCGI / Cell ID:  {p.get('nr_ncgi', 'N/A')} (PCI: {p.get('nr_pci', 'N/A')})")
        print(f"ARFCN:           {p.get('nr_arfcn', 'N/A')}")
        print(f"RSRP:            {p.get('nr_rsrp', p.get('rsrp', 'N/A'))} dBm")
        print(f"RSRQ:            {p.get('nr_rsrq', p.get('rsrq', 'N/A'))} dB")
        print(f"SINR:            {p.get('nr_sinr', p.get('sinr', 'N/A'))} dB")
        print(f"MIMO / Mod:      {p.get('mimo', 'N/A')} / {p.get('modulation', 'N/A')}")
        print(f"Default APN:     {p.get('default_apn', 'N/A')}")
        print(f"BLER:            {p.get('bler', 0)}%")
    else:
        print(rf_info)


def cmd_network(odu):
    print("\n--- [ Network Interfaces & Routing ] ---")
    out = odu.run_command("ip -br a; echo '--- ROUTES ---'; ip route")
    print(out)

    print("\n--- [ EoGRE Tunnel Rules ] ---")
    eogre = odu.ubus_call("luxslam", "eogre", {"cmd": "get", "class": "rule_list"})
    print(json.dumps(eogre, indent=2))


def cmd_hpue(odu, set_val=None):
    if set_val is not None:
        print(f"[+] Setting HPUE Power Class 1.5 to: {set_val}")
        res = odu.at_cmd(f"AT+QPC1DOT5={set_val}")
        print(res)
    else:
        res = odu.at_cmd("AT+QPC1DOT5?")
        print("\n--- [ HPUE Power Class 1.5 Status ] ---")
        print(res)


def cmd_cell_lock(odu, lock_params=None, unlock=False):
    if unlock:
        print("[+] Unlocking 5G cell lock...")
        print(odu.at_cmd('AT+QNWLOCK="common/5g",0'))
    elif lock_params:
        pci, freq, scs, band = lock_params
        print(f"[+] Locking to 5G Cell: PCI={pci}, FREQ={freq}, SCS={scs}, BAND={band}")
        print(odu.at_cmd(f'AT+QNWLOCK="common/5g",{pci},{freq},{scs},{band}'))
    else:
        print("\n--- [ Current 5G Cell Lock Status ] ---")
        print(odu.at_cmd('AT+QNWLOCK="common/5g"'))


def cmd_band_lock(odu, band=None):
    if band:
        print(f"[+] Locking 5G Band to: {band}")
        print(odu.at_cmd(f'AT+QNWPREFCFG="nr5g_band",{band}'))
    else:
        print("\n--- [ Current 5G Band Preference ] ---")
        print(odu.at_cmd('AT+QNWPREFCFG="nr5g_band"'))


def cmd_sim_slot(odu, slot=None):
    if slot:
        print(f"[+] Switching SIM Slot to: {slot} (1=Physical SIM, 2=eSIM)")
        print(odu.at_cmd(f'AT+QUIMSLOT={slot}'))
        odu.run_command(f"echo '{slot}' > /data/sim_slot_pref")
    else:
        print("\n--- [ Current Active SIM Slot ] ---")
        curr = odu.at_cmd('AT+QUIMSLOT?')
        print(curr)
        print(odu.run_command("luxcmds sys slot"))
        if "+QUIMSLOT: 2" in curr:
            eid = odu.run_command("luxcmds sys eid", timeout=8.0).replace("SUCCESS:", "").strip()
            if eid and "FAIL" not in eid:
                print(f"eSIM EID:         {mask_eid(eid)}")
        else:
            print("Slot Type:        Physical Nano-SIM (Slot 1)")


def cmd_bluetooth(odu, state=None):
    if state:
        print(f"[+] Setting Bluetooth to: {state}")
        print(odu.run_command(f"/data/bt/set_bt {state}"))
    else:
        print("\n--- [ Bluetooth Status ] ---")
        print(odu.run_command("luxcmds sys bluetooth"))
        print(odu.run_command("hciconfig hci0"))


def cmd_gps(odu, action="loc"):
    if action == "on":
        print("[+] Turning ON Qualcomm GNSS receiver...")
        print(odu.at_cmd("AT+QGPS=1"))
    elif action == "off":
        print("[+] Turning OFF Qualcomm GNSS receiver...")
        print(odu.at_cmd("AT+QGPSEND"))
    else:
        print("\n--- [ GPS Live Location Coordinates ] ---")
        print(odu.at_cmd("AT+QGPSLOC=2"))


def cmd_temp(odu):
    print("\n--- [ 17-Zone Thermal Sensor Telemetry ] ---")
    print(odu.at_cmd("AT+QTEMP"))


def cmd_shell(port):
    print(f"\n[+] Opening direct serial shell on {port} (Ctrl+C to exit)...")
    os.system(f"picocom -b 115200 {port} || screen {port} 115200")


def main():
    parser = argparse.ArgumentParser(description="JODU52140 Reverse Engineering CLI")
    parser.add_argument("--port", default="/dev/ttyUSB0", help="UART port (default: /dev/ttyUSB0)")
    parser.add_argument("--baud", type=int, default=115200, help="Baud rate (default: 115200)")
    parser.add_argument("--adb", action="store_true", help="Connect via ADB instead of serial UART")

    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("info", help="Display hardware & firmware device info")
    subparsers.add_parser("rf", help="Display 5G SA RF metrics (RSRP, SINR, PCI, Band)")
    subparsers.add_parser("network", help="Display network interfaces and EoGRE configuration")
    subparsers.add_parser("temp", help="Query 17-zone hardware thermal telemetry")
    subparsers.add_parser("shell", help="Launch interactive serial console")

    # HPUE
    hpue_parser = subparsers.add_parser("hpue", help="Query or set HPUE Power Class 1.5 (+29 dBm)")
    hpue_parser.add_argument("--set", choices=["0", "1"], help="Enable (1) or Disable (0) HPUE PC1.5")

    # Cell Lock
    cell_parser = subparsers.add_parser("cell-lock", help="Query or lock 5G physical cell tower")
    cell_parser.add_argument("--lock-5g", nargs=4, metavar=("PCI", "FREQ", "SCS", "BAND"), help="Lock to 5G cell")
    cell_parser.add_argument("--unlock", action="store_true", help="Clear cell lock")

    # Band Lock
    band_parser = subparsers.add_parser("band-lock", help="Query or lock 5G bands (e.g. 78)")
    band_parser.add_argument("--set", help="Specify 5G band to lock (e.g. 78)")

    # SIM Slot
    sim_parser = subparsers.add_parser("sim-slot", help="Query or switch SIM slot (1=Physical SIM, 2=eSIM)")
    sim_parser.add_argument("--set", choices=["1", "2"], help="Switch active SIM slot")

    # Bluetooth
    bt_parser = subparsers.add_parser("bluetooth", help="Query or control Realtek Bluetooth")
    bt_parser.add_argument("--set", choices=["on", "off"], help="Turn Bluetooth on or off")

    # GPS
    gps_parser = subparsers.add_parser("gps", help="Query or control GNSS GPS receiver")
    gps_parser.add_argument("--action", choices=["on", "off", "loc"], default="loc", help="Action to perform")

    # Generic ubus / cmd
    ubus_parser = subparsers.add_parser("ubus", help="Call ubus API on target")
    ubus_parser.add_argument("object", help="ubus object name (e.g., luxslam)")
    ubus_parser.add_argument("method", help="ubus method name (e.g., 5g, sys, lan)")
    ubus_parser.add_argument("params", nargs="?", default="{}", help="JSON params string")

    cmd_parser = subparsers.add_parser("cmd", help="Run arbitrary command on target")
    cmd_parser.add_argument("exec_cmd", help="Command string to execute")

    args = parser.parse_args()

    if args.command == "shell":
        cmd_shell(args.port)
        return

    odu = ODUConsole(port=args.port, baudrate=args.baud, use_adb=args.adb)
    odu.connect()

    try:
        if args.command == "info":
            cmd_info(odu)
        elif args.command == "rf":
            cmd_rf(odu)
        elif args.command == "network":
            cmd_network(odu)
        elif args.command == "hpue":
            cmd_hpue(odu, set_val=args.set)
        elif args.command == "cell-lock":
            cmd_cell_lock(odu, lock_params=args.lock_5g, unlock=args.unlock)
        elif args.command == "band-lock":
            cmd_band_lock(odu, band=args.set)
        elif args.command == "sim-slot":
            cmd_sim_slot(odu, slot=args.set)
        elif args.command == "bluetooth":
            cmd_bluetooth(odu, state=args.set)
        elif args.command == "gps":
            cmd_gps(odu, action=args.action)
        elif args.command == "temp":
            cmd_temp(odu)
        elif args.command == "ubus":
            params = json.loads(args.params)
            res = odu.ubus_call(args.object, args.method, params)
            print(json.dumps(res, indent=2))
        elif args.command == "cmd":
            res = odu.run_command(args.exec_cmd)
            print(res)
    finally:
        odu.close()


if __name__ == "__main__":
    main()
