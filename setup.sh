#!/bin/bash
# FPGA Controller - Master Setup/Reset Script
# Works for initial setup or network reset deployment

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
sudo apt install -y python3 python3-pip python3-paho-mqtt mosquitto mosquitto-clients git avahi-daemon

# Enable mDNS discovery
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon

# Setup MQTT broker
echo "⚙️  Configuring MQTT broker..."
sudo systemctl stop mosquitto 2>/dev/null || true

sudo tee /etc/mosquitto/mosquitto.conf > /dev/null <<EOF
allow_anonymous true
listener 1883 0.0.0.0
protocol mqtt
listener 9001 0.0.0.0  
protocol websockets
log_dest file /var/log/mosquitto/mosquitto.log
log_type error
log_type warning
log_type notice
log_type information
EOF

sudo mkdir -p /var/log/mosquitto /var/lib/mosquitto

# Fix mosquitto service
sudo tee /etc/systemd/system/mosquitto.service > /dev/null <<EOF
[Unit]
Description=Mosquitto MQTT Broker
After=network.target

[Service]
Type=notify
NotifyAccess=main
ExecStart=/usr/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf
User=root
Group=root
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Setup project directory
echo "📁 Setting up project..."
mkdir -p ~/fpga_controller
cd ~/fpga_controller

# Copy controller files (assumes run from deployment directory)
if [ -f "pi-controller/fpga_gpio_controller.py" ]; then
    cp pi-controller/fpga_gpio_controller.py .
    cp version2-webserver/start_webserver.py .
    chmod +x fpga_gpio_controller.py start_webserver.py
else
    echo "⚠️  Controller files not found. Please run from deployment directory."
    exit 1
fi

# Create FPGA controller service
sudo tee /etc/systemd/system/fpga-controller.service > /dev/null <<EOF
[Unit]
Description=FPGA GPIO Controller
After=network.target mosquitto.service
Wants=mosquitto.service

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
After=network.target fpga-controller.service
Wants=fpga-controller.service

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

# Enable and start services
echo "🚀 Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable mosquitto fpga-controller fpga-webserver
sudo systemctl start mosquitto
sleep 2
sudo systemctl start fpga-controller
sleep 2
sudo systemctl start fpga-webserver

# Test GPIO
echo "🧪 Testing GPIO..."
if command -v pinctrl &> /dev/null; then
    for pin in 18 19 20 21 22 23; do
        sudo pinctrl set $pin op
        sudo pinctrl set $pin dh
        sudo pinctrl set $pin dl
    done
    echo "✅ GPIO test complete"
else
    echo "❌ pinctrl not available"
fi

# Create IP detection script
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
echo "Service Status:"
systemctl is-active mosquitto && echo "  ✅ MQTT Broker: Running" || echo "  ❌ MQTT Broker: Stopped"
systemctl is-active fpga-controller && echo "  ✅ GPIO Controller: Running" || echo "  ❌ GPIO Controller: Stopped"  
systemctl is-active fpga-webserver && echo "  ✅ Web Server: Running" || echo "  ❌ Web Server: Stopped"
EOF

chmod +x ~/get-pi-info.sh

# Wait for services to start
sleep 5

# Check service status
echo "🔍 Checking services..."
sudo systemctl status mosquitto --no-pager -l
sudo systemctl status fpga-controller --no-pager -l
sudo systemctl status fpga-webserver --no-pager -l

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Run './get-pi-info.sh' to see connection details"
echo "Reboot recommended to ensure hostname takes effect"
echo ""
read -p "Reboot now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo reboot
fi
