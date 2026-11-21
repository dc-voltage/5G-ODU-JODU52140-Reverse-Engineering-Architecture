# JODU52140 Ubus API Reference

The `luxslam` daemon exposes a comprehensive JSON-RPC management interface via OpenWrt's `ubus`.

## 1. System & Device Commands (`sys`)

### Query Device Information
```bash
ubus call luxslam sys '{"cmd":"get","class":"device"}'
```
**Example Response:**
```json
{
  "cmd": "get",
  "class": "device",
  "paramtable": {
    "product_name": "Jio ODU",
    "device_model": "JODU52140",
    "hardware_version": "HW_V1.3",
    "odm": "LUXSHARE",
    "oui": "7CBF77",
    "serial_number": "RNOODFKQXXXXXXX",
    "base_macaddr": "7C:BF:77:XX:XX:XX",
    "uptime": 1231,
    "secure_boot_status": 0
  }
}
```

### Query Firmware Information
```bash
ubus call luxslam sys '{"cmd":"get","class":"firmware"}'
```
**Example Response:**
```json
{
  "cmd": "get",
  "class": "firmware",
  "paramtable": {
    "software_version": "JODU52140_REL_01_23_00_S",
    "fw_upload_path": "/usrdata/cache/ufs/update.zip",
    "build_date": 1749721800,
    "fw_upgrade_result": 0
  }
}
```

---

## 2. 5G Cellular Commands (`5g`)

### Query Serving Cell Metrics
```bash
ubus call luxslam 5g '{"cmd":"get","class":"serving_cell"}'
```
**Example Response:**
```json
{
  "cmd": "get",
  "class": "serving_cell",
  "paramtable": {
    "status": "SA",
    "rrc_state": "Connected",
    "nr5g": "n78",
    "bandwidth": 100,
    "plmn": "405862",
    "ncgi": "405862XXXXXXXXXX",
    "pci": 408,
    "nr_arfcn": 634080,
    "nr_rsrp": -109,
    "nr_rsrq": -11,
    "nr_sinr": 8,
    "mimo": "2x2",
    "modulation": "QPSK",
    "default_apn": "jioairfibermu",
    "bler": 46
  }
}
```

### Query Neighbor Cells
```bash
ubus call luxslam 5g '{"cmd":"get","class":"neighbor_cell"}'
```

### Query eSIM Profiles & Status
```bash
ubus call luxslam 5g '{"cmd":"get","class":"esim"}'
```

---

## 3. Network & Tunneling Commands (`eogre`, `lan`, `firewall`)

### Query EoGRE Tunnel Rules
```bash
ubus call luxslam eogre '{"cmd":"get","class":"rule_list"}'
```

### Query LAN IP & DHCP Configuration
```bash
ubus call luxslam lan '{"cmd":"get","class":"ipv4"}'
ubus call luxslam lan '{"cmd":"get","class":"dhcpv4"}'
```

### Query IP Passthrough Status
```bash
ubus call luxslam ip_passthrough '{"cmd":"get","class":"general"}'
```
