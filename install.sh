#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Installing Monitor Service ==="
chmod +x "$SCRIPT_DIR/service/monitor-service.py"
cp "$SCRIPT_DIR/service/com.github.fullmetal.monitor.service" \
   "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable com.github.fullmetal.monitor.service
systemctl --user restart com.github.fullmetal.monitor.service
echo "Service started."

echo ""
echo "=== Installing RAM & Swap Widget ==="
kpackagetool6 -t Plasma/Applet -i "$SCRIPT_DIR/ram-swap-widget" 2>/dev/null || \
kpackagetool6 -t Plasma/Applet -u "$SCRIPT_DIR/ram-swap-widget"

echo ""
echo "=== Installing CPU Widget ==="
kpackagetool6 -t Plasma/Applet -i "$SCRIPT_DIR/cpu-widget" 2>/dev/null || \
kpackagetool6 -t Plasma/Applet -u "$SCRIPT_DIR/cpu-widget"

echo ""
echo "=== Installing Uptime Widget ==="
kpackagetool6 -t Plasma/Applet -i "$SCRIPT_DIR/uptime-widget" 2>/dev/null || \
kpackagetool6 -t Plasma/Applet -u "$SCRIPT_DIR/uptime-widget"

echo ""
echo "=== All widgets installed! ==="
echo "Right-click panel → Add Widgets → search: 'RAM & Swap', 'CPU', 'Uptime & Reboot'"
