#!/usr/bin/env python3
"""
JODU52140 Reverse Engineering & Management Tool
Automated CLI for inspecting, querying, and managing the Jio 5G Outdoor Unit (JODU52140)
via UART Serial Console (1.8V TTL, 115200 8N1).
"""

import argparse
import json
import os
import sys
import time

try:
    import serial
except ImportError:
    sys.exit("Error: pyserial is required. Install via 'pip install pyserial'")


class ODUConsole:
    def __init__(self, port="/dev/ttyUSB0", baudrate=115200, timeout=1.5):
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.ser = None

    def connect(self):
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

    def run_command(self, cmd, timeout=3.0):
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
    if len(s) > 6:
        return s[:6] + "X" * (len(s) - 6)
    return s


def mask_ncgi(ncgi):
    if not ncgi or ncgi == "N/A":
        return ncgi
    s = str(ncgi)
    if len(s) > 6:
        return s[:6] + "X" * (len(s) - 6)
    return s


def cmd_info(odu):
    print("\n--- [ Device Identification ] ---")
    dev = odu.ubus_call("luxslam", "sys", {"cmd": "get", "class": "device"})
    fw = odu.ubus_call("luxslam", "sys", {"cmd": "get", "class": "firmware"})

    if "paramtable" in dev:
        p = dev["paramtable"]
        print(f"Product Name:     {p.get('product_name', 'N/A')}")
        print(f"Device Model:     {p.get('device_model', 'N/A')}")
        print(f"Hardware Version: {p.get('hardware_version', 'N/A')}")
        print(f"ODM:              {p.get('odm', 'N/A')} (OUI: {p.get('oui', 'N/A')})")
        print(f"Serial Number:    {mask_serial(p.get('serial_number', 'N/A'))}")
        print(f"Base MAC:         {mask_mac(p.get('base_macaddr', 'N/A'))}")
        print(f"Uptime:           {p.get('uptime', 0)} seconds")
    else:
        print(dev)

    if "paramtable" in fw:
        fp = fw["paramtable"]
        print(f"Software Version: {fp.get('software_version', 'N/A')}")
        print(f"Firmware Path:    {fp.get('fw_upload_path', 'N/A')}")


def cmd_rf(odu):
    print("\n--- [ 5G Cellular & RF Metrics ] ---")
    res = odu.ubus_call("luxslam", "5g", {"cmd": "get", "class": "serving_cell"})
    if "paramtable" in res:
        p = res["paramtable"]
        print(f"Status:          {p.get('status', 'N/A')} ({p.get('rrc_state', 'N/A')})")
        print(f"5G Band:         {p.get('nr5g', 'N/A')} (Bandwidth: {p.get('bandwidth', 0)} MHz)")
        print(f"PLMN:            {p.get('plmn', 'N/A')} (Jio SA)")
        print(f"NCGI / Cell ID:  {mask_ncgi(p.get('ncgi', 'N/A'))} (PCI: {p.get('pci', 'N/A')})")
        print(f"ARFCN:           {p.get('nr_arfcn', 'N/A')}")
        print(f"RSRP:            {p.get('nr_rsrp', p.get('rsrp', 'N/A'))} dBm")
        print(f"RSRQ:            {p.get('nr_rsrq', p.get('rsrq', 'N/A'))} dB")
        print(f"SINR:            {p.get('nr_sinr', p.get('sinr', 'N/A'))} dB")
        print(f"MIMO / Mod:      {p.get('mimo', 'N/A')} / {p.get('modulation', 'N/A')}")
        print(f"Default APN:     {p.get('default_apn', 'N/A')}")
        print(f"BLER:            {p.get('bler', 0)}%")
    else:
        print(res)


def cmd_network(odu):
    print("\n--- [ Network Interfaces & Routing ] ---")
    out = odu.run_command("ip -br a; echo '--- ROUTES ---'; ip route")
    print(out)

    print("\n--- [ EoGRE Tunnel Rules ] ---")
    eogre = odu.ubus_call("luxslam", "eogre", {"cmd": "get", "class": "rule_list"})
    print(json.dumps(eogre, indent=2))


def cmd_shell(port):
    print(f"\n[+] Opening direct serial shell on {port} (Ctrl+C to exit)...")
    os.system(f"picocom -b 115200 {port} || screen {port} 115200")


def main():
    parser = argparse.ArgumentParser(description="JODU52140 Reverse Engineering CLI")
    parser.add_argument("--port", default="/dev/ttyUSB0", help="UART port (default: /dev/ttyUSB0)")
    parser.add_argument("--baud", type=int, default=115200, help="Baud rate (default: 115200)")

    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("info", help="Display hardware & firmware device info")
    subparsers.add_parser("rf", help="Display 5G SA RF metrics (RSRP, SINR, PCI, Band)")
    subparsers.add_parser("network", help="Display network interfaces and EoGRE configuration")
    subparsers.add_parser("shell", help="Launch interactive serial console")

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

    odu = ODUConsole(port=args.port, baudrate=args.baud)
    odu.connect()

    try:
        if args.command == "info":
            cmd_info(odu)
        elif args.command == "rf":
            cmd_rf(odu)
        elif args.command == "network":
            cmd_network(odu)
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
