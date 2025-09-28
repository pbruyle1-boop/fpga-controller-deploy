[MAIN README.md](https://github.com/user-attachments/files/22437116/MAIN.README.md)
# FPGA Controller 

## Quick Start

```bash

git clone https://github.com/pbruyle1-boop/fpga-controller-deploy.git
cd fpga-controller-deploy
chmod +x *.sh pi-controller/*.sh
./setup.sh
```
May have to run service restart after setup
```bash
sudo systemctl restart fpga-controller fpga-webserver
```

After setup, get connection info:
```bash
./get-pi-info.sh
```

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

### Find Pi Information
```bash
./get-pi-info.sh
```

### Web Interface Access
- **Direct IP**: `http://(pi-ip):8080/` (replace with actual IP)
- **mDNS**: `http://fpga-controller.local:8080/`
  
## Management

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
├── version2-webserver/
│   ├── fpga_controller_webserver.html
│   ├── start_webserver.py
├── pi-controller/
│   ├── fpga_gpio_controller.py
│   └── config/
└── README.md                         
```
