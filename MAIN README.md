# FPGA Controller - Complete Deployment Package

A robust, production-ready FPGA LED controller system with two interface options and automatic deployment capabilities.

## Quick Start

```bash
# git clone <repo-url>
cd fpga-controller-deploy
chmod +x *.sh pi-controller/*.sh
./setup.sh
```

After setup, get connection info:
```bash
./get-pi-info.sh
```

## Package Contents

### Core System
- **High-side UDN2981A compatible** (GPIO HIGH = LED ON)
- **6 GPIO pins total** (2 per FPGA: User + Loaded)
- **Auto-connects on boot** - zero maintenance
- **Network reset capable** - re-run setup.sh anytime

### Two Interface Versions

#### Version 1: Standalone HTML
- **File**: `version1-standalone/fpga_controller_standalone.html`
- **Use**: Distribute to users, they open locally
- **Connection**: Users enter Pi IP address manually
- **Best for**: Multiple users, different devices

#### Version 2: Web Server
- **File**: `version2-webserver/fpga_controller_webserver.html`
- **Use**: Hosted on Pi at `http://pi-ip:8080/`
- **Connection**: Auto-detects Pi IP
- **Best for**: Centralized access, mobile devices

## Hardware Setup

### GPIO Pin Assignments
| FPGA | User LED | Loaded LED |
|------|----------|------------|
| FPGA 1 | GPIO 18 | GPIO 19 |
| FPGA 2 | GPIO 20 | GPIO 21 |
| FPGA 3 | GPIO 22 | GPIO 23 |

### Wiring (High-Side UDN2981A)
```
Pi GPIO → UDN2981A Input → UDN2981A Output → LED → Current Limiting Resistor → Ground
```

**Logic**: GPIO HIGH (3.3V) = LED ON, GPIO LOW (0V) = LED OFF

## Deployment Scenarios

### New Pi Setup
```bash
git clone <repo>
cd fpga-controller-deploy
./setup.sh
```

### Network Change/Reset
```bash
cd fpga-controller-deploy
./setup.sh  # Same script handles reset
```

### After Power Cycle
Everything starts automatically - no action needed.

## Access Methods

### Find Pi Information
```bash
./get-pi-info.sh
```

### Web Interface Access
- **Direct IP**: `http://192.168.1.100:8080/` (replace with actual IP)
- **mDNS**: `http://fpga-controller.local:8080/`
- **Standalone**: Download HTML file, open locally

### Mobile Access
Create QR code pointing to `http://[pi-ip]:8080/` for easy mobile access.

## Service Management

### View Logs
```bash
sudo journalctl -u fpga-controller.service -f
sudo journalctl -u fpga-webserver.service -f
```

### Restart Services
```bash
sudo systemctl restart fpga-controller fpga-webserver
```

## Testing

### Manual GPIO Test
```bash
# Test LED control directly
sudo pinctrl set 18 dh  # Turn on FPGA1 User LED
sudo pinctrl set 18 dl  # Turn off FPGA1 User LED
```

### MQTT Test
```bash
# Turn on Dan's indicator on FPGA1
mosquitto_pub -h localhost -t 'fpga/command/fpga1/user' -m 'dan'

# Turn on loaded indicator
mosquitto_pub -h localhost -t 'fpga/command/fpga1/loaded' -m 'true'
```

### Multimeter Verification
- Black probe to Pi ground
- Red probe to GPIO pin
- LED ON command: Should read 3.3V
- LED OFF command: Should read 0V

## Troubleshooting

### Services Won't Start
```bash
sudo systemctl status fpga-controller
sudo journalctl -u fpga-controller
```

### Web Interface Won't Connect
1. Check Pi IP: `./get-pi-info.sh`
2. Verify services: `sudo systemctl status fpga-webserver mosquitto`
3. Test MQTT: `mosquitto_pub -h localhost -t test -m hello`

### GPIO Not Responding
1. Verify pinctrl: `sudo pinctrl get 18`
2. Check controller logs: `sudo journalctl -u fpga-controller -f`
3. Test manually: `sudo pinctrl set 18 dh`

### Network Issues
Re-run setup after network changes:
```bash
./setup.sh
```

## File Structure

```
fpga-controller-deploy/
├── setup.sh                           # Master setup script
├── get-pi-info.sh                     # System information
├── version1-standalone/
│   ├── fpga_controller_standalone.html
│   └── README.md
├── version2-webserver/
│   ├── fpga_controller_webserver.html
│   ├── start_webserver.py
│   └── README.md
├── pi-controller/
│   ├── fpga_gpio_controller.py
│   └── config/
└── README.md                          # This file
```

## Security Notes

- MQTT allows anonymous connections (local network use)
- Web server accessible to network (no authentication)
- Pi runs with elevated GPIO privileges
- Consider firewall rules for production use

## License

MIT License - See LICENSE file for details.
