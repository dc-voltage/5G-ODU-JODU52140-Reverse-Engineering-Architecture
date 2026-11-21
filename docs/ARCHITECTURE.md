# Jio 5G Outdoor Unit (JODU52140) Architecture & Reverse Engineering Specification

## 1. Overview

The **JODU52140** is a 5G Standalone (SA) Outdoor Unit (ODU) designed for Reliance Jio's **JioAirFiber** Fixed Wireless Access (FWA) deployment. The hardware is manufactured by **Luxshare-ICT** (ODM) using the **Qualcomm SDXLEMUR** (Snapdragon X65/X62) 5G modem processor running a Qualcomm Reference Embedded Linux (QTI) platform with OpenWrt-derived userland utilities.

```mermaid
graph TD
    A["5G Radio Antenna (n78 100MHz)"] --> B["Qualcomm SDXLEMUR Baseband"]
    B --> C["Qualcomm IPA (rmnet_ipa0)"]
    C --> D["Linux Kernel 5.4.242-perf (armv7l)"]
    D --> E["luxslam Daemon (ubus API)"]
    E --> F["Lua Control Plane (/usr/lib/lua/)"]
    F --> G["uhttpd Web Management (HTTPS :443)"]
    F --> H["EoGRE Tunnel / Bridge0"]
    H --> I["Ethernet PHY (eth0 / PoE 169.254.51.1)"]
    I --> J["Indoor Unit (Jio IDU Router)"]
    E --> K["TR-069 cwmpc (cr.acs.oss.jio.com)"]
    E --> L["Telemetry MQTT rjiledc (wfr.dinj.jfdca.net)"]
    B --> M["1.8V UART Console (/dev/ttyUSB0)"]
```

---

## 2. Hardware Specifications

| Component | Specification |
| :--- | :--- |
| **Model** | JODU52140 (Jio ODU) |
| **ODM / Vendor** | Luxshare Precision Industry Co., Ltd. (OUI: `7C:BF:77`) |
| **SoC / Modem** | Qualcomm Technologies, Inc. SDXLEMUR (Snapdragon X65/X62) |
| **CPU Architecture** | ARMv7 Processor rev 5 (v7l), 32-bit |
| **Flash Storage** | NAND Flash (34 MTD partitions) with UBI / SquashFS |
| **RAM** | ~256MB DDR |
| **Ethernet** | Gigabit PoE (Power over Ethernet) Interface (`eth0`) |
| **SIM Support** | Physical SIM + eSIM (GSMA Remote SIM Provisioning RSPv2) |
| **Bluetooth / BLE** | Onboard BLE for mobile alignment app (`quec_jio_bt`) |
| **Debug Interface** | 1.8V TTL UART @ 115200 8N1 |

---

## 3. Flash & Partition Layout

The NAND Flash is partitioned into 34 MTD blocks:

```mermaid
flowchart LR
    subgraph Bootloader
        mtd0["mtd0: sbl"] --> mtd1["mtd1: mibib"]
        mtd1 --> mtd6["mtd6: tz (TrustZone)"]
        mtd6 --> mtd10["mtd10: xbl_config"]
        mtd10 --> mtd16["mtd16: abl / uefi"]
    end
    subgraph Modem_Subsystem
        mtd25["mtd25: ipa_fw"]
        mtd30["mtd30: modem"]
    end
    subgraph Linux_OS
        mtd27["mtd27: boot (Kernel)"]
        mtd31["mtd31: system (SquashFS rootfs)"]
        mtd33["mtd33: usrdata (UBI read-write)"]
    end
```

### Partition Highlights:
* **`mtd27 (boot)`**: Linux kernel (`5.4.242-perf`) and Flattened Device Tree (FDT).
* **`mtd30 (modem)`**: Qualcomm Hexagon DSP modem firmware image (Q6 modem).
* **`mtd31 (system)`**: Read-only SquashFS root filesystem mounted at `/dev/root`.
* **`mtd33 (usrdata)`**: UBI NAND volume providing writable persistence mounted on `/data`, `/etc`, and `/usrdata`.

---

## 4. Software Stack & Control Plane

The operating system is **QTI Linux reference nogplv3 distro** (`LE.UM.6.2.3.r1-03100-SDX65.0`). The system initializes through `systemd`, which coordinates Qualcomm radio daemons, the Luxshare orchestration engine (`luxslam`), and OpenWrt networking tools.

```mermaid
sequenceDiagram
    participant User as "Web / CLI / TR-069"
    participant uhttpd as "uhttpd (:443)"
    participant Lua as "Lux Lua Controllers (/usr/lib/lua)"
    participant ubus as "ubus IPC"
    participant luxslam as "luxslam Native Daemon"
    participant Modem as "Qualcomm Modem (SMD/QMI)"

    User->>uhttpd: HTTPS POST /jiooscc or /cgi-bin/app
    uhttpd->>Lua: lux-uhttpd.lua dispatch
    Lua->>ubus: ubus call luxslam <method> <payload>
    ubus->>luxslam: IPC dispatch
    luxslam->>Modem: QMI / SMD / AT queries
    Modem-->>luxslam: Response (RF metrics / Cell data)
    luxslam-->>ubus: JSON result
    ubus-->>Lua: Lua table
    Lua-->>uhttpd: JSON HTTP response
    uhttpd-->>User: 200 OK
```

### Key Services & Daemons:
1. **`luxslam`**: Proprietary Luxshare daemon acting as the primary middleware bus on `ubus`. It bridges hardware commands, AT/QMI interfaces, and network configurations.
2. **`uhttpd`**: OpenWrt lightweight web server listening on port `443` (HTTPS) serving an Angular Single Page Application (SPA) with Jio styling.
3. **`cwmpc`**: TR-069 client reporting to Jio ACS (`https://acs.oss.jio.com:9443/ftacs-digest/ACS`).
4. **`rjiledc`**: Enterprise Data Collector daemon publishing telemetry metrics via MQTT over TLS to `wfr.dinj.jfdca.net:1887`.
5. **`quec_jio_bt`**: Bluetooth pairing daemon facilitating antenna alignment using technician mobile apps.
6. **`adbd`**: Android Debug Bridge daemon listening locally on `127.0.0.1:5037`.

---

## 5. Network Architecture & Data Flow

The ODU operates in three configurable network modes:

1. **EoGRE Mode (Default for JioAirFiber)**:
   * 5G cellular data is received over the `rmnet_ipa0` / `rmnet_data0` interface.
   * An Ethernet-over-GRE (EoGRE) tunnel encapsulates Layer-2 packets between the ODU and the Indoor Unit (IDU) router.
   * Ensures seamless public IP passthrough and centralized traffic routing at the IDU.

2. **Bridge Mode**:
   * Bridges the 5G data interface directly to `bridge0` / `eth0` with IP Passthrough to the connected router.

3. **Router Mode**:
   * ODU performs NAT, runs `dnsmasq` for DHCP/DNS, and assigns IPs in the `192.168.225.0/24` subnet.

```mermaid
graph LR
    subgraph Cellular_Plane
        Tower["Jio 5G gNodeB (Band n78)"] -->|"100MHz SA"| Q6["Qualcomm SDX65 Modem"]
        Q6 -->|"IPA Hardware Accel"| rmnet["rmnet_data0 (APN: jioairfibermu)"]
    end
    subgraph ODU_Core
        rmnet --> EoGRE["EoGRE Tunnel Engine"]
        EoGRE --> br0["bridge0"]
        br0 --> eth["Gigabit PHY (eth0)"]
    end
    subgraph Customer_Premises
        eth -->|"PoE Cable"| IDU["Jio IDU (Indoor Router)"]
        IDU --> WiFi["Wi-Fi 6 Clients"]
    end
```

---

## 6. Voice Calling Subsystem (VoNR / VoLTE Architecture)

The JODU52140 incorporates a dedicated cellular voice subsystem capable of 5G SA Voice-over-NR (VoNR) and 4G Voice-over-LTE (VoLTE).

```mermaid
graph TD
    Client["VoIP Client / JioCall App (LAN)"] -->|TCP :6666| Server["jiocall_server (/usr/bin/jiocall_server)"]
    Server -->|QMI Voice v02| QCCI["libqmi_cci.so.1 / libqmiservices.so.1"]
    QCCI -->|IPC| Baseband["Qualcomm SDX65 Modem Core"]
    Baseband -->|IMS APN profile_id=2| IMS["Jio 5G IMS Core (VoNR / VoLTE)"]
```

### Key Components:
* **`jiocall_server`**: A native Linux daemon listening on TCP port `6666`. It accepts socket connections from local network clients, handling call establishment, DTMF, and call termination commands.
* **QMI Voice Interface**: Interacts with Qualcomm's `voice_get_service_object_internal_v02` to bridge application layer commands to the modem baseband.
* **Dedicated IMS APN**: Configured automatically via `/sbin/lux_add_ims_apn.sh` with `apn='ims'`, `apn_id='2'`, and `apn_connection_type='3'` (IP multi-PDP context).
* **Modem IMS Stack**: Enabled via `AT+QCFG="ims",2,0` to register the baseband with Jio's IP Multimedia Subsystem core.

---

## 7. RF Subsystem & Power Class 1.5 (HPUE)

```mermaid
flowchart LR
    Modem["SDX65 Baseband"] --> RFFE["RF Front End (RFFE)"]
    RFFE --> PA["Power Amplifier (+29 dBm)"]
    PA --> HPUE{"HPUE PC1.5 Enabled?"}
    HPUE -->|Yes (+29 dBm / 800mW)| Ant["High-Gain Directional Antennas"]
    HPUE -->|No (+23 dBm / 200mW)| Ant
```

### High Power User Equipment (HPUE):
* **Standard Power Class 3:** Maximum output power is limited to +23 dBm (200 mW).
* **HPUE Power Class 1.5:** The JODU52140 RF power amplifiers support Power Class 1.5 on 3GPP Band n78 (3300–3800 MHz), raising maximum transmit power to **+29 dBm (800 mW)**.
* **Enabling Command:** `AT+QPC1DOT5=1`. Enforced across reboots in `/usrdata/custom_unhide/apply_unhide.sh`.
* **5G Cell & Band Lock:** The baseband firmware supports physical cell locking via `AT+QNWLOCK="common/5g",<pci>,<freq>,<scs>,<band>` and band locking via `AT+QNWPREFCFG="nr5g_band"`.

---

## 8. Hardware Peripherals & Telemetry

### Dual SIM & eSIM:
* **Physical SIM (Slot 1):** Internal nano-SIM slot wired directly to the baseband USIM interface.
* **eSIM (Slot 2):** Onboard Thales eUICC chip (EID: `890330234263XXXXXXXXXXXXXXXXXX`) managed via LPA daemon (`lpad`) with GSMA RSPv2 root certificates (`/data/GSMA_RSPv2-Root.pem`).
* **Switching:** Controlled via `AT+QUIMSLOT=1` or `AT+QUIMSLOT=2`.

### Bluetooth 5.x:
* **Hardware:** Realtek Bluetooth controller connected over high-speed UART (`/dev/ttyHS0`).
* **Stack:** Initialized with `rtk_hciattach` and managed via BlueZ (`bluetoothd`, `bluealsa`, `/data/bt/set_bt`).

### Satellite GNSS:
* **Receiver:** Embedded Qualcomm SDX65 multi-constellation engine (GPS, GLONASS, Galileo, BeiDou).
* **NMEA Output:** Accessible via `/dev/ttyUSB2` when activated via `AT+QGPS=1`.

### Thermal Management:
* Real-time thermal telemetry across 17 distinct hardware sensors (Power Amplifiers, Modem Core, PMIC, XO) queried via `AT+QTEMP`.

