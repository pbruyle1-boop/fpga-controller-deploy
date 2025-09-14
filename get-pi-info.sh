#!/bin/bash
# FPGA Controller Pi Information Script
# Displays current network and service information

echo "=================================================="
echo "FPGA Controller Pi - System Information"
echo "=================================================="

# Network Information
echo "📡 Network Information:"
echo "  Hostname: $(hostname)"
echo "  IP Address: $(hostname -I | awk '{print $1}')"
echo "  mDNS Name: $(hostname).local"
echo ""

# Web Interface URLs
IP=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)

echo "🌐 Web Interface Access:"
echo "  Direct IP: http://${IP}:8080/"
echo "  mDNS: http://${HOSTNAME}.local:8080/"
echo "  Main Interface: http://${IP}:8080/fpga_controller.html"
echo ""

# Service Status
echo "⚙️  Service Status:"
if systemctl is-active --quiet mosquitto; then
    echo "  ✅ MQTT Broker: Running"
else
    echo "  ❌ MQTT Broker: Stopped"
fi

if systemctl is-active --quiet fpga-controller; then
    echo "  ✅ GPIO Controller: Running"
else
    echo "  ❌ GPIO Controller: Stopped"
fi

if systemctl is-active --quiet fpga-webserver; then
    echo "  ✅ Web Server: Running"
else
    echo "  ❌ Web Server: Stopped"
fi

echo ""

# GPIO Pin Information
echo "📍 GPIO Pin Assignments:"
echo "  FPGA 1: User=GPIO18, Loaded=GPIO19"
echo "  FPGA 2: User=GPIO20, Loaded=GPIO21"
echo "  FPGA 3: User=GPIO22, Loaded=GPIO23"
echo ""

# Quick Commands
echo "🔧 Quick Commands:"
echo "  View logs: sudo journalctl -u fpga-controller.service -f"
echo "  Restart services: sudo systemctl restart fpga-controller fpga-webserver"
echo "  Check this info: ./get-pi-info.sh"
echo ""

# QR Code suggestion for mobile access
echo "📱 For mobile access, create QR code for:"
echo "  http://${IP}:8080/"
echo ""

# Network test
echo "🧪 Network Test:"
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo "  ✅ Internet connectivity: OK"
else
    echo "  ⚠️  Internet connectivity: Limited"
fi

# MQTT test
echo ""
echo "🔌 MQTT Test:"
if timeout 2s mosquitto_sub -h localhost -t test -C 1 &> /dev/null & \
   sleep 0.5 && mosquitto_pub -h localhost -t test -m "test" &> /dev/null; then
    echo "  ✅ MQTT communication: OK"
    wait
else
    echo "  ❌ MQTT communication: Failed"
fi

echo ""
echo "=================================================="
