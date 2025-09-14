#!/usr/bin/env python3
"""
FPGA Controller Web Server
Auto-serves the web interface on port 8080
"""

import http.server
import socketserver
import os
import socket
import logging

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def get_ip_address():
    """Get the local IP address"""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except Exception:
        return "localhost"

def get_hostname():
    """Get the hostname"""
    try:
        return socket.gethostname()
    except:
        return "fpga-controller"

class FPGAHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Add CORS headers
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()
    
    def log_message(self, format, *args):
        """Override to use Python logging"""
        logger.info("%s - - [%s] %s" % (
            self.address_string(),
            self.log_date_time_string(),
            format % args
        ))

def create_index_html():
    """Create an index.html that redirects to the main interface"""
    index_content = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>FPGA Controller</title>
    <meta http-equiv="refresh" content="0; url=fpga_controller.html">
</head>
<body>
    <p>Redirecting to <a href="fpga_controller.html">FPGA Controller</a>...</p>
</body>
</html>'''
    
    try:
        with open('index.html', 'w') as f:
            f.write(index_content)
        logger.info("Created index.html redirect")
    except Exception as e:
        logger.warning(f"Could not create index.html: {e}")

def main():
    PORT = 8080
    
    # Ensure we're in the right directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    
    # Create webserver version of HTML if it doesn't exist
    if not os.path.exists('fpga_controller.html'):
        logger.error("fpga_controller.html not found!")
        logger.error("Please ensure the HTML file is in the same directory")
        return 1
    
    # Create index.html for convenience
    create_index_html()
    
    ip_address = get_ip_address()
    hostname = get_hostname()
    
    Handler = FPGAHTTPRequestHandler
    
    try:
        with socketserver.TCPServer(("", PORT), Handler) as httpd:
            logger.info("FPGA Controller Web Server Starting")
            logger.info(f"Hostname: {hostname}")
            logger.info(f"Local IP: {ip_address}")
            logger.info(f"Serving at: http://{ip_address}:{PORT}")
            logger.info(f"mDNS: http://{hostname}.local:{PORT}")
            logger.info("")
            logger.info("Access URLs:")
            logger.info(f"  http://{ip_address}:{PORT}/")
            logger.info(f"  http://{ip_address}:{PORT}/fpga_controller.html")
            logger.info(f"  http://{hostname}.local:{PORT}/")
            logger.info("")
            logger.info("Press Ctrl+C to stop the server")
            
            httpd.serve_forever()
            
    except KeyboardInterrupt:
        logger.info("Shutting down web server...")
        return 0
    except OSError as e:
        if e.errno == 98:  # Address already in use
            logger.error(f"Port {PORT} is already in use!")
            logger.error("The web server may already be running")
            return 1
        else:
            logger.error(f"Error starting server: {e}")
            return 1

if __name__ == "__main__":
    exit(main())
