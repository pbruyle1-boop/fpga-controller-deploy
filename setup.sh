#!/bin/bash
# FPGA Controller - Master Setup/Reset Script
# Updated for VerneMQ external broker and local MQTT library

set -e

echo "================================================"
echo "FPGA Controller - Complete Setup/Reset"
echo "================================================"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo "❌ Don't run this script as root! Run as regular user (pi)"
  exit 1
fi

# Set hostname
echo "🏷️  Setting hostname to fpga-controller..."
echo "fpga-controller" | sudo tee /etc/hostname > /dev/null
sudo sed -i 's/127.0.1.1.*/127.0.1.1\tfpga-controller/' /etc/hosts

# Update system
echo "📦 Updating system..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "📦 Installing packages..."
sudo apt install -y python3 python3-pip python3-paho-mqtt git avahi-daemon wget

# Enable mDNS discovery
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon

# Stop and disable local Mosquitto (using external VerneMQ)
echo "⚙️  Disabling local Mosquitto (using external VerneMQ)..."
sudo systemctl stop mosquitto 2>/dev/null || true
sudo systemctl disable mosquitto 2>/dev/null || true

# Setup project directory
echo "📁 Setting up project..."
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
else
    echo "⚠️  Controller files not found. Please run from deployment directory."
    exit 1
fi

# Download MQTT library locally to avoid CDN issues
echo "📦 Downloading MQTT JavaScript library..."
wget -q https://cdn.jsdelivr.net/npm/mqtt/dist/mqtt.min.js -O mqtt.min.js
if [ $? -ne 0 ]; then
    echo "⚠️  Primary CDN failed, trying alternative..."
    wget -q https://unpkg.com/mqtt/dist/mqtt.min.js -O mqtt.min.js
    if [ $? -ne 0 ]; then
        echo "❌ MQTT library download failed. Internet connection required."
        exit 1
    fi
fi

# Verify MQTT library downloaded
if [ -f "mqtt.min.js" ] && [ -s "mqtt.min.js" ]; then
    echo "✅ MQTT library downloaded successfully"
else
    echo "❌ MQTT library download verification failed"
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

# Configure static IP
echo "🌐 Configuring static IP..."
sudo tee /etc/dhcpcd.conf > /dev/null <<EOF
# DHCP Client Configuration for FPGA Controller
# Static IP configuration for eth0

# Allow users of this group to interact with dhcpcd via the control socket.
hostname

# Use the hardware address of the interface for the Client ID.
clientid

# Persist interface configuration when dhcpcd exits.
persistent

# Rapid commit support.
option rapid_commit

# A list of options to request from the DHCP server.
option domain_name_servers, domain_name, domain_search, host_name
option classless_static_routes
option interface_mtu

# A ServerID is required by RFC2131.
require dhcp_server_identifier

# Generate SLAAC address using the hardware address of the interface
slaac hwaddr

# Static IP configuration for eth0 interface
interface eth0
static ip_address=172.30.81.82/24
static routers=172.30.81.1
static domain_name_servers=8.8.8.8 8.8.4.4
EOF

# Enable and start services
echo "🚀 Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable fpga-controller fpga-webserver
sudo systemctl start fpga-controller
sleep 2
sudo systemctl start fpga-webserver

# Test GPIO
echo "🧪 Testing GPIO..."
if command -v pinctrl &> /dev/null; then
    for pin in 18 19 20 21 22 23 24 25 26 27 2 3; do
        sudo pinctrl set $pin op
        sudo pinctrl set $pin dh
        sudo pinctrl set $pin dl
    done
    echo "✅ GPIO test complete"
else
    echo "⚠️  pinctrl not available"
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
echo "  External VerneMQ Broker: 172.30.81.106:1883"
echo "  WebSocket Port: 8083"
echo ""
echo "Service Status:"
systemctl is-active fpga-controller && echo "  ✅ GPIO Controller: Running" || echo "  ❌ GPIO Controller: Stopped"  
systemctl is-active fpga-webserver && echo "  ✅ Web Server: Running" || echo "  ❌ Web Server: Stopped"
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
echo "📊 Checking services..."
sudo systemctl status fpga-controller --no-pager -l
sudo systemctl status fpga-webserver --no-pager -l

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Configuration Summary:"
echo "  ✅ Static IP: 172.30.81.82"
echo "  ✅ External VerneMQ: 172.30.81.106:1883"
echo "  ✅ Local MQTT Library: Downloaded"
echo "  ✅ All services configured"
echo ""
echo "Run './get-pi-info.sh' to see connection details"
echo "Network restart recommended: sudo systemctl restart dhcpcd"
echo ""
read -p "Restart networking now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo systemctl restart dhcpcd
    echo "Network restarted. IP should now be 172.30.81.82"
fi
