# FPGA Controller - Web Server Version

This version hosts the web interface directly on the Raspberry Pi, providing automatic access without requiring file distribution.

## How It Works

The Pi runs a web server on port 8080 that serves the control interface. Users simply navigate to the Pi's IP address in any web browser.

## Access Methods

### Direct IP Access
```
http://192.168.1.100:8080/
```
(Replace with your Pi's actual IP address)

### mDNS Access (if available)
```
http://fpga-controller.local:8080/
```

### Mobile-Friendly
Works perfectly on phones and tablets - just visit the URL.

## Features

- **Auto-connects** to Pi when page loads
- **No manual setup** required by users
- **Mobile responsive** design
- **Real-time updates** from Pi
- **Centralized hosting** - one URL for everyone

## For System Administrators

### Service Management
The web server runs as a systemd service:

```bash
# Check status
sudo systemctl status fpga-webserver

# Restart if needed
sudo systemctl restart fpga-webserver

# View logs
sudo journalctl -u fpga-webserver -f
```

### Port Configuration
Default port is 8080. To change:

1. Edit `start_webserver.py`
2. Change `PORT = 8080` to desired port
3. Restart service: `sudo systemctl restart fpga-webserver`

### Firewall Considerations
If using a firewall, allow port 8080:
```bash
sudo ufw allow 8080
```

## For End Users

### Getting the URL
Ask your administrator for the Pi's IP address, or look for:
- Network device list in router
- "fpga-controller" in network browser
- mDNS at `fpga-controller.local:8080`

### Using the Interface
1. Navigate to the provided URL
2. Page automatically connects to Pi
3. Use dropdown controls to set LED states
4. Click "Update" to apply changes
5. Visual LEDs show current status

### Troubleshooting
- **Page won't load**: Check IP address, verify Pi is powered on
- **"Connection failed"**: Pi services may be down, contact administrator
- **Interface not responding**: Refresh page, check network connection

## Technical Details

- Built-in HTTP server on port 8080
- Auto-detects Pi IP for MQTT connection
- WebSocket communication on port 9001
- Serves static HTML/CSS/JavaScript
- CORS headers enabled for browser compatibility

## Mobile Access

Create QR codes pointing to your Pi's URL for easy mobile access:
- `http://[pi-ip]:8080/`

Perfect for shop floor or field use where typing URLs is impractical.

## Advantages

- **Zero distribution** - no files to send to users
- **Always up-to-date** - single source of truth
- **Mobile friendly** - responsive design
- **Network discovery** - mDNS support
- **Centralized** - one URL for all users

## Files

- `fpga_controller_webserver.html` - Main interface
- `start_webserver.py` - Web server implementation
- Auto-created `index.html` - Redirects to main interface
- 
