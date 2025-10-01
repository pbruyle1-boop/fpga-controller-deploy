#!/bin/bash
# FPGA Controller - Master Setup/Reset Script
# Updated for VerneMQ external broker and local MQTT library

set -e

echo "================================================"
echo "FPGA Controller - Setup/Reset"
echo "================================================"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo " Don't run this script as root! Run as regular user (pi)"
  exit 1
fi

# Set hostname
echo " Setting hostname to fpga-controller..."
echo "fpga-controller" | sudo tee /etc/hostname > /dev/null
sudo sed -i 's/127.0.1.1.*/127.0.1.1\tfpga-controller/' /etc/hosts

# Update system
echo " Updating system..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "Installing packages..."
sudo apt install -y python3 python3-pip python3-paho-mqtt git avahi-daemon wget

# Enable mDNS discovery
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon

# Stop and disable local Mosquitto (using external VerneMQ)
echo " Disabling local Mosquitto (using external VerneMQ)..."
sudo systemctl stop mosquitto 2>/dev/null || true
sudo systemctl disable mosquitto 2>/dev/null || true

# Setup project directory
echo " Setting up project..."
mkdir -p ~/fpga_controller
cd ~/fpga_controller

# Copy controller files (assumes run from deployment directory)
if [ -f "../fpga-controller-deploy/pi-controller/fpga_gpio_controller.py" ]; then
    cp ../fpga-controller-deploy/pi-controller/fpga_gpio_controller.py .
    cp ../fpga-controller-deploy/version2-webserver/start_webserver.py .
    cp ../fpga-controller-deploy/version2-webserver/fpga_controller_webserver.html ./fpga_controller.html
    chmod +x fpga_gpio_controller.py start_webserver.py
elif [ -f "pi-controller/fpga_gpio_controller.py" ]; then
    cp pi-controller/fpga_gpio_controller.py .
    cp version2-webserver/start_webserver.py .
    cp version2-webserver/fpga_controller_webserver.html ./fpga_controller.html
    chmod +x fpga_gpio_controller.py start_webserver.py
    exit 1
fi

# Create FPGA controller service
sudo tee /etc/systemd/system/fpga-controller.service > /dev/null <<EOF
[Unit]
Description=FPGA GPIO Controller
After=network.target

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=/home/pi/fpga_controller
ExecStart=/usr/bin/python3 /home/pi/fpga_controller/fpga_gpio_controller.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Create web server service
sudo tee /etc/systemd/system/fpga-webserver.service > /dev/null <<EOF
[Unit]
Description=FPGA Web Server
After=network.target

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=/home/pi/fpga_controller
ExecStart=/usr/bin/python3 /home/pi/fpga_controller/start_webserver.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Configure static IP using NetworkManager
echo " Configuring static IP with"
sudo nmcli con mod "Wired connection 1" ipv4.addresses 172.30.81.83/24 2>/dev/null || \
sudo nmcli con mod "$(nmcli -t -f NAME con show | head -n1)" ipv4.addresses 172.30.81.83/24

sudo nmcli con mod "Wired connection 1" ipv4.gateway 172.30.81.15 2>/dev/null || \
sudo nmcli con mod "$(nmcli -t -f NAME con show | head -n1)" ipv4.gateway 172.30.81.15

sudo nmcli con mod "Wired connection 1" ipv4.dns 8.8.8.8 2>/dev/null || \
sudo nmcli con mod "$(nmcli -t -f NAME con show | head -n1)" ipv4.dns 8.8.8.8

sudo nmcli con mod "Wired connection 1" ipv4.method manual 2>/dev/null || \
sudo nmcli con mod "$(nmcli -t -f NAME con show | head -n1)" ipv4.method manual

echo "Static IP configured"

# Enable and start services
echo "Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable fpga-controller fpga-webserver
sudo systemctl start fpga-controller
sleep 2
sudo systemctl start fpga-webserver

# Test GPIO
echo "Testing GPIO..."
if command -v pinctrl &> /dev/null; then
    for pin in 18 19 20 21 22 23 24 25 26 27 2 3; do
        sudo pinctrl set $pin op
        sudo pinctrl set $pin dh
        sudo pinctrl set $pin dl
    done
    echo "GPIO test complete"
else
    echo " pinctrl not available"
fi

# Create info script
cat > ~/get-pi-info.sh << 'EOF'
#!/bin/bash
echo "=== FPGA Controller Pi Information ==="
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "mDNS Address: fpga-controller.local"
echo ""
echo "Web Interface URLs:"
echo "  http://$(hostname -I | awk '{print $1}'):8080/fpga_controller.html"
echo "  http://fpga-controller.local:8080/fpga_controller.html"
echo ""
echo "MQTT Configuration:"
echo " Broker: 172.30.81.106:1883"
echo "  WebSocket Port: 8083"
echo ""
echo "Service Status:"
systemctl is-active fpga-controller && echo "  GPIO Controller: Running" || echo "   GPIO Controller: Stopped"  
systemctl is-active fpga-webserver && echo "  Web Server: Running" || echo "   Web Server: Stopped"
echo ""
echo "GPIO Pin Assignments:"
echo "  FPGA1: R=18, G=19, B=20, Loaded=27"
echo "  FPGA2: R=21, G=22, B=23, Loaded=2"
echo "  FPGA3: R=24, G=25, B=26, Loaded=3"
EOF

chmod +x ~/get-pi-info.sh

# Wait for services to start
sleep 5

# Check service status
echo " Checking services..."
sudo systemctl status fpga-controller --no-pager -l
sudo systemctl status fpga-webserver --no-pager -l

echo ""
echo " Setup complete!"
echo ""
echo "Configuration Summary:"
echo "  Static IP: 172.30.81.83"
echo "  Serving at: 172.30.81.106:1883"
echo "  All services configured"
echo ""
echo "Run './get-pi-info.sh' to see connection details"
echo "Network restart recommended to apply static IP: sudo nmcli con up \"Wired connection 1\""
echo ""
read -p "Apply network changes now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo nmcli con up "Wired connection 1" 2>/dev/null || \
    sudo nmcli con up "$(nmcli -t -f NAME con show | head -n1)" 2>/dev/null
    echo "Network changes applied. IP should now be 172.30.81.83"
    echo "Run 'ip addr show eth0' to verify"
fi
