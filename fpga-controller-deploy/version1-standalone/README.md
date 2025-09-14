# FPGA Controller - Standalone Version

This version provides a standalone HTML file that users can download and run locally on any device with a web browser.

## Usage

### For End Users

1. **Download** the `fpga_controller_standalone.html` file
2. **Open** the file in any web browser (Chrome, Firefox, Safari, Edge)
3. **Enter** your FPGA Controller Pi's IP address in the connection field
4. **Click Connect** to establish communication with the Pi
5. **Control** LEDs using the interface

### Finding the Pi IP Address

Ask your system administrator for the Pi's IP address, or if you have access to the Pi:

```bash
./get-pi-info.sh
```

This will display the current IP address and connection URLs.

### Connection Examples

- If Pi IP is `192.168.1.100`, enter: `192.168.1.100`
- If using mDNS, enter: `fpga-controller.local`

## Features

- **No installation required** - just open the HTML file
- **Works on any device** - phones, tablets, computers
- **Manual IP entry** - connect to any Pi on the network
- **Real-time control** - immediate LED response
- **Status indicators** - visual feedback for each FPGA

## LED Controls

### User LED
- **None**: LED off
- **Dan**: Red LED on
- **Nate**: Blue LED on  
- **Ben**: Green LED on

### Loaded LED
- **Off**: LED off
- **Loaded**: Green LED on

## Troubleshooting

### "Connection Failed"
- Verify the Pi IP address is correct
- Ensure you're on the same network as the Pi
- Check that the Pi services are running

### "Not Connected" Error
- Click the Connect button first
- Wait for "Connected" status before using controls

### Can't Find Pi IP
- Ask your network administrator
- Check router's connected devices list
- Try `fpga-controller.local` if mDNS is available

## Distribution

This file can be:
- Emailed to users
- Shared via network drive
- Downloaded from a website
- Copied to USB drives

No special software installation required - just a web browser.

## Technical Details

- Uses MQTT over WebSocket (port 9001)
- Compatible with all modern browsers
- No server-side dependencies
- Direct Pi-to-browser communication
