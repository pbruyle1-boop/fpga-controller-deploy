#!/usr/bin/env python3
"""
FPGA GPIO Controller - High-Side UDN2981A with RGB LEDs
Controls 9 RGB pins (3 per FPGA: Red, Green, Blue) + 3 Loaded pins
HIGH-SIDE LOGIC: GPIO HIGH = LED ON, GPIO LOW = LED OFF
"""

import paho.mqtt.client as mqtt
import subprocess
import time
import logging
import signal
import sys
import socket
from threading import Lock

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/fpga_controller.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# GPIO Pin Assignments - RGB LEDs (3 pins per FPGA) + Loaded LEDs
GPIO_PINS = {
    'fpga1': {
        'red': 18,      # User LED Red
        'green': 19,    # User LED Green
        'blue': 20,     # User LED Blue
        'loaded': 27    # Loaded LED
    },
    'fpga2': {
        'red': 21,      # User LED Red
        'green': 22,    # User LED Green
        'blue': 23,     # User LED Blue
        'loaded': 2     # Loaded LED
    },
    'fpga3': {
        'red': 24,      # User LED Red
        'green': 25,    # User LED Green
        'blue': 26,     # User LED Blue
        'loaded': 3     # Loaded LED
    }
}

current_state = {
    'fpga1': {'user': 'none', 'loaded': False},
    'fpga2': {'user': 'none', 'loaded': False},
    'fpga3': {'user': 'none', 'loaded': False}
}

def get_hostname():
    """Get current hostname"""
    try:
        return socket.gethostname()
    except:
        return "fpga-controller"

def get_ip_address():
    """Get current IP address"""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except:
        return "localhost"

class FPGAController:
    def __init__(self):
        self.mqtt_client = None
        self.running = False
        self.setup_gpio()
        signal.signal(signal.SIGINT, self.cleanup_and_exit)
        signal.signal(signal.SIGTERM, self.cleanup_and_exit)
        
    def run_pinctrl(self, command):
        """Run sudo pinctrl command"""
        try:
            cmd = f"sudo pinctrl {command}"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            return result.returncode == 0, result.stdout.strip()
        except Exception as e:
            logger.error(f"Error running pinctrl: {e}")
            return False, ""
    
    def set_pin_output(self, pin):
        """Set pin as output"""
        success, output = self.run_pinctrl(f"set {pin} op")
        return success
    
    def set_pin_high(self, pin):
        """Set pin high (3.3V) - LED ON for high-side UDN2981A"""
        success, output = self.run_pinctrl(f"set {pin} dh")
        if success:
            logger.info(f"GPIO {pin} -> HIGH (3.3V) - LED ON")
        return success
    
    def set_pin_low(self, pin):
        """Set pin low (0V) - LED OFF for high-side UDN2981A"""
        success, output = self.run_pinctrl(f"set {pin} dl")
        if success:
            logger.info(f"GPIO {pin} -> LOW (0V) - LED OFF")
        return success
    
    def setup_gpio(self):
        """Initialize all GPIO pins - start with LEDs OFF"""
        logger.info("Setting up GPIO pins for high-side UDN2981A with RGB LEDs:")
        for fpga_id, pins in GPIO_PINS.items():
            for led_type, pin in pins.items():
                if not self.set_pin_output(pin):
                    raise Exception(f"Failed to set GPIO {pin} as output")
                if not self.set_pin_low(pin):  # LOW = LED OFF for high-side
                    raise Exception(f"Failed to set GPIO {pin} low")
                logger.info(f"  {fpga_id} {led_type.upper()} -> GPIO {pin} (OFF)")
        logger.info("GPIO setup complete - all LEDs OFF")
    
    def setup_mqtt(self):
        """Setup MQTT client"""
        self.mqtt_client = mqtt.Client()
        self.mqtt_client.on_connect = self.on_connect
        self.mqtt_client.on_message = self.on_message
        self.mqtt_client.connect("localhost", 1883, 60)
    
    def on_connect(self, client, userdata, flags, rc):
        """MQTT connect callback"""
        if rc == 0:
            logger.info("Connected to MQTT broker")
            
            # Subscribe to command topics
            topics = []
            for fpga_id in GPIO_PINS.keys():
                for cmd_type in ['user', 'loaded']:
                    topic = f"fpga/command/{fpga_id}/{cmd_type}"
                    topics.append(topic)
                    client.subscribe(topic)
            
            logger.info(f"Subscribed to {len(topics)} topics")
        else:
            logger.error(f"MQTT connection failed: {rc}")
    
    def on_message(self, client, userdata, msg):
        """Handle MQTT messages"""
        try:
            topic = msg.topic
            payload = msg.payload.decode('utf-8').strip()
            logger.info(f"Received: {topic} = '{payload}'")
            
            # Parse topic: fpga/command/fpga1/user
            parts = topic.split('/')
            if len(parts) == 4 and parts[0] == 'fpga' and parts[1] == 'command':
                fpga_id = parts[2]    # fpga1, fpga2, fpga3
                cmd_type = parts[3]   # user, loaded
                
                if fpga_id in GPIO_PINS and cmd_type in ['user', 'loaded']:
                    if cmd_type == 'user':
                        self.handle_user_command(fpga_id, payload)
                    elif cmd_type == 'loaded':
                        self.handle_loaded_command(fpga_id, payload)
                    
                    # Publish status back
                    status_topic = f"fpga/status/{fpga_id}/{cmd_type}"
                    client.publish(status_topic, payload)
                    
        except Exception as e:
            logger.error(f"Error processing message: {e}")
    
    def set_rgb_color(self, fpga_id, color):
        """Set RGB LED to specific color"""
        pins = GPIO_PINS[fpga_id]
        red_pin = pins['red']
        green_pin = pins['green']
        blue_pin = pins['blue']
        
        # Turn off all RGB pins first
        self.set_pin_low(red_pin)
        self.set_pin_low(green_pin)
        self.set_pin_low(blue_pin)
        
        # Set the appropriate color
        if color == 'dan':  # Red
            self.set_pin_high(red_pin)
            logger.info(f"{fpga_id} RGB LED -> RED (Dan)")
        elif color == 'ben':  # Green
            self.set_pin_high(green_pin)
            logger.info(f"{fpga_id} RGB LED -> GREEN (Ben)")
        elif color == 'blake':  # Blue
            self.set_pin_high(blue_pin)
            logger.info(f"{fpga_id} RGB LED -> BLUE (Blake)")
        else:  # 'none' or unknown
            logger.info(f"{fpga_id} RGB LED -> OFF (None)")
    
    def handle_user_command(self, fpga_id, user):
        """Handle user selection command"""
        current_state[fpga_id]['user'] = user
        self.set_rgb_color(fpga_id, user)
    
    def handle_loaded_command(self, fpga_id, loaded_str):
        """Handle loaded status command"""
        pin = GPIO_PINS[fpga_id]['loaded']
        loaded = loaded_str.lower() == 'true'
        current_state[fpga_id]['loaded'] = loaded
        
        # HIGH-SIDE LOGIC: HIGH = LED ON, LOW = LED OFF
        if loaded:
            self.set_pin_high(pin)  # LED ON
            logger.info(f"{fpga_id} Loaded LED ON")
        else:
            self.set_pin_low(pin)   # LED OFF
            logger.info(f"{fpga_id} Loaded LED OFF")
    
    def test_all_leds(self):
        """Test all LEDs"""
        logger.info("Testing all LEDs...")
        
        for fpga_id in GPIO_PINS.keys():
            logger.info(f"Testing {fpga_id} RGB...")
            
            # Test Red
            self.set_rgb_color(fpga_id, 'dan')
            time.sleep(0.3)
            
            # Test Green
            self.set_rgb_color(fpga_id, 'ben')
            time.sleep(0.3)
            
            # Test Blue
            self.set_rgb_color(fpga_id, 'blake')
            time.sleep(0.3)
            
            # Turn off
            self.set_rgb_color(fpga_id, 'none')
            time.sleep(0.1)
            
            # Test loaded LED
            loaded_pin = GPIO_PINS[fpga_id]['loaded']
            self.set_pin_high(loaded_pin)
            time.sleep(0.3)
            self.set_pin_low(loaded_pin)
            time.sleep(0.1)
        
        logger.info("LED test complete")
    
    def cleanup_and_exit(self, signum=None, frame=None):
        """Clean shutdown - turn all LEDs OFF"""
        logger.info("Cleaning up...")
        for fpga_id, pins in GPIO_PINS.items():
            for led_type, pin in pins.items():
                self.set_pin_low(pin)   # LOW = LED OFF for high-side
        if self.mqtt_client:
            self.mqtt_client.disconnect()
        logger.info("Cleanup complete")
        sys.exit(0)
    
    def run(self):
        """Main run loop"""
        hostname = get_hostname()
        ip_address = get_ip_address()
        
        logger.info("FPGA GPIO Controller - High-Side UDN2981A with RGB LEDs")
        logger.info(f"Hostname: {hostname}")
        logger.info(f"IP Address: {ip_address}")
        logger.info("GPIO Pin Assignments:")
        for fpga_id, pins in GPIO_PINS.items():
            pin_list = ", ".join([f"{led.upper()}={pin}" for led, pin in pins.items()])
            logger.info(f"  {fpga_id.upper()}: {pin_list}")
        
        logger.info("High-Side Logic: HIGH=LED ON, LOW=LED OFF")
        logger.info("RGB Colors: Dan=Red, Ben=Green, Blake=Blue")
        
        self.test_all_leds()
        self.setup_mqtt()
        self.running = True
        self.mqtt_client.loop_start()
        
        logger.info("Controller ready! Listening for commands...")
        
        try:
            while self.running:
                time.sleep(10)
        except KeyboardInterrupt:
            self.cleanup_and_exit()

if __name__ == "__main__":
    controller = FPGAController()
    controller.run()
