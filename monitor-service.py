#!/usr/bin/env python3
"""Shared D-Bus service for Plasma monitor widgets (RAM, CPU, Uptime)."""

import json
import os
import re
import subprocess
import time
from collections import deque

from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
import dbus
import dbus.service
import dbus.mainloop.glib

BUS_NAME = "com.github.fullmetal.monitor"
INTERFACE = "com.github.fullmetal.monitor"
HISTORY_SIZE = 300  # ~10 min at 2s intervals

# --- Globals ---
ram_history = deque(maxlen=HISTORY_SIZE)
swap_history = deque(maxlen=HISTORY_SIZE)
cpu_history = deque(maxlen=HISTORY_SIZE)
last_cpu_total = 0
last_cpu_idle = 0
last_per_core = {}


def _read_file(path):
    try:
        with open(path, "r") as f:
            return f.read()
    except Exception:
        return ""


def _parse_meminfo():
    data = {}
    for line in _read_file("/proc/meminfo").splitlines():
        parts = line.split()
        if len(parts) >= 2:
            key = parts[0].rstrip(":")
            val = int(parts[1])
            data[key] = val
    return data


def _bytes_to_gb(b):
    return round(b / (1024 * 1024), 1)


def _get_ram_info():
    m = _parse_meminfo()
    total = m.get("MemTotal", 0)
    available = m.get("MemAvailable", 0)
    used = total - available
    swap_total = m.get("SwapTotal", 0)
    swap_free = m.get("SwapFree", 0)
    swap_used = swap_total - swap_free

    ram_pct = round((used / total * 100) if total else 0, 1)
    swap_pct = round((swap_used / swap_total * 100) if swap_total else 0, 1)

    ram_history.append(ram_pct)
    swap_history.append(swap_pct)

    return {
        "ram_used_gb": _bytes_to_gb(used),
        "ram_total_gb": _bytes_to_gb(total),
        "ram_percent": ram_pct,
        "ram_history": list(ram_history),
        "swap_used_gb": _bytes_to_gb(swap_used),
        "swap_total_gb": _bytes_to_gb(swap_total),
        "swap_percent": swap_pct,
        "swap_history": list(swap_history),
    }


def _get_top_processes(sort_key="%mem", limit=5):
    try:
        out = subprocess.check_output(
            ["ps", "-eo", "comm,%cpu,%mem,rss", "--no-headers", f"--sort=-{sort_key}"],
            timeout=3,
            text=True,
        )
        procs = []
        for line in out.strip().splitlines()[:limit]:
            # Parse from right: rss is last, mem is second to last, cpu is third to last
            parts = line.split()
            if len(parts) >= 4:
                rss = int(parts[-1])
                mem_pct = float(parts[-2])
                cpu_pct = float(parts[-3])
                name = " ".join(parts[:-3])[:20]
                procs.append({
                    "name": name,
                    "percent": cpu_pct,
                    "mem_percent": mem_pct,
                    "rss_kb": rss,
                })
        return procs
    except Exception:
        return []


def _get_top_cpu(limit=5):
    try:
        out = subprocess.check_output(
            ["ps", "-eo", "comm,%cpu,etime", "--no-headers", "--sort=-%cpu"],
            timeout=3,
            text=True,
        )
        procs = []
        for line in out.strip().splitlines()[:limit]:
            parts = line.split()
            if len(parts) >= 3:
                time_val = parts[-1]
                cpu_pct = float(parts[-2])
                name = " ".join(parts[:-2])[:20]
                procs.append({
                    "name": name,
                    "percent": cpu_pct,
                    "time": time_val,
                })
        return procs
    except Exception:
        return []


def _read_cpu_stat():
    global last_cpu_total, last_cpu_idle, last_per_core

    lines = _read_file("/proc/stat").splitlines()
    totals = {}
    for line in lines:
        if line.startswith("cpu"):
            parts = line.split()
            name = parts[0]
            vals = [int(x) for x in parts[1:]]
            total = sum(vals)
            idle_val = vals[3] if len(vals) > 3 else 0
            totals[name] = (total, idle_val)

    # Per-core
    per_core = {}
    for name, (total, idle_val) in totals.items():
        if name == "cpu":
            continue
        if name in last_per_core:
            prev_total, prev_idle = last_per_core[name]
            d_total = total - prev_total
            d_idle = idle_val - prev_idle
            if d_total > 0:
                per_core[name] = round((1 - d_idle / d_total) * 100, 1)
    last_per_core = totals

    # Overall
    if "cpu" in totals:
        total, idle_val = totals["cpu"]
        d_total = total - last_cpu_total
        d_idle = idle_val - last_cpu_idle
        last_cpu_total = total
        last_cpu_idle = idle_val
        if d_total > 0:
            return round((1 - d_idle / d_total) * 100, 1), per_core
    return 0.0, per_core


def _get_uptime_info():
    raw = _read_file("/proc/uptime").strip().split()
    uptime_sec = float(raw[0]) if raw else 0
    days = int(uptime_sec // 86400)
    hours = int((uptime_sec % 86400) // 3600)
    minutes = int((uptime_sec % 3600) // 60)

    if hours < 12:
        level = "green"
    elif hours < 15:
        level = "yellow"
    else:
        level = "red"

    # Reboot history from journalctl
    reboots = []
    try:
        out = subprocess.check_output(
            ["journalctl", "--list-boots", "--no-pager", "-q", "-n", "10"],
            timeout=3,
            text=True,
        )
        for line in out.strip().splitlines():
            parts = line.split(None, 4)
            if len(parts) >= 5:
                reboots.append({
                    "id": parts[0],
                    "date": f"{parts[1]} {parts[2]} {parts[3]}",
                    "desc": parts[4] if len(parts) > 4 else "",
                })
    except Exception:
        pass

    return {
        "uptime_seconds": int(uptime_sec),
        "days": days,
        "hours": hours,
        "minutes": minutes,
        "level": level,
        "reboots": reboots,
    }


def _get_updates_info():
    try:
        out = subprocess.check_output(
            ["apt", "list", "--upgradable"],
            timeout=30,
            text=True,
            stderr=subprocess.DEVNULL,
        )
        count = len([l for l in out.strip().splitlines() if "/" in l])
        return {"count": count, "text": str(count)}
    except Exception:
        return {"count": 0, "text": "0"}


class MonitorService(dbus.service.Object):
    def __init__(self):
        bus = dbus.SessionBus()
        bus.request_name(BUS_NAME)
        super().__init__(bus, "/Monitor")

    @dbus.service.method(INTERFACE, out_signature="s")
    def GetRamInfo(self):
        info = _get_ram_info()
        info["top_ram"] = _get_top_processes(sort_key="%mem", limit=5)
        info["top_swap"] = []
        try:
            out = subprocess.check_output(
                ["ps", "-eo", "comm,%mem,rss", "--no-headers", "--sort=-rss"],
                timeout=3, text=True,
            )
            for line in out.strip().splitlines()[:5]:
                parts = line.split(None, 2)
                if len(parts) >= 3:
                    info["top_swap"].append({
                        "name": parts[0][:20],
                        "percent": float(parts[1]),
                        "rss_kb": int(parts[2]),
                    })
        except Exception:
            pass
        return json.dumps(info)

    @dbus.service.method(INTERFACE, out_signature="s")
    def GetCpuInfo(self):
        pct, per_core = _read_cpu_stat()
        cpu_history.append(pct)

        cores = {}
        for k in sorted(per_core.keys()):
            cores[k] = per_core[k]

        return json.dumps({
            "cpu_percent": pct,
            "cpu_history": list(cpu_history),
            "per_core": cores,
            "top_cpu": _get_top_cpu(limit=5),
        })

    @dbus.service.method(INTERFACE, out_signature="s")
    def GetUptimeInfo(self):
        return json.dumps(_get_uptime_info())

    @dbus.service.method(INTERFACE, out_signature="s")
    def GetUpdatesInfo(self):
        return json.dumps(_get_updates_info())

    @dbus.service.method(INTERFACE, out_signature="s")
    def GetAll(self):
        return json.dumps({
            "ram": _get_ram_info(),
            "cpu_percent": _read_cpu_stat()[0],
            "uptime": _get_uptime_info(),
        })


def main():
    DBusGMainLoop(set_as_default=True)
    MonitorService()
    loop = GLib.MainLoop()
    loop.run()


if __name__ == "__main__":
    main()
