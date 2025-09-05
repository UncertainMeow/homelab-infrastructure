#!/usr/bin/env python3
"""
Caddy Service Manager
Automatically manages Caddy configurations for discovered services
Integrates with NetBox and Technitium DNS for complete automation
"""

import os
import json
import logging
import requests
import yaml
from pathlib import Path
from typing import Dict, List, Optional, Any
from datetime import datetime
import subprocess
import tempfile
import shutil

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class CaddyServiceManager:
    def __init__(self):
        self.netbox_url = os.getenv('NETBOX_URL', 'http://localhost:8080')
        self.netbox_token = os.getenv('NETBOX_API_TOKEN')
        self.gitlab_server = os.getenv('GITLAB_SERVER', 'git.doofus.co')
        self.domain = os.getenv('BASE_DOMAIN', 'doofus.co')
        self.cloudflare_token = os.getenv('CLOUDFLARE_API_TOKEN')
        
        # Caddy configuration paths
        self.caddy_config_dir = Path('/opt/caddy')
        self.services_config_dir = self.caddy_config_dir / 'services'
        self.main_caddyfile = self.caddy_config_dir / 'Caddyfile'
        self.backup_dir = self.caddy_config_dir / 'backups'
        
        # Service discovery rules
        self.service_rules = {
            # Port-based service detection
            'web': {'ports': [80, 8080, 3000, 8000], 'protocol': 'http'},
            'secure_web': {'ports': [443, 8443], 'protocol': 'https'},
            'api': {'ports': [8080, 9000, 3001], 'protocol': 'http'},
            'database_admin': {'ports': [8081, 8082, 5050], 'protocol': 'http'},
            'monitoring': {'ports': [3000, 9090, 9091], 'protocol': 'http'},
            'docs': {'ports': [8000, 4000], 'protocol': 'http'}
        }
        
        # Service templates
        self.service_templates = {
            'web': '''
{hostname} {{
    tls {{
        dns cloudflare {{env.CLOUDFLARE_API_TOKEN}}
    }}
    reverse_proxy {ip}:{port} {{
        header_up Host {{upstream_hostport}}
        header_up X-Real-IP {{remote_host}}
        header_up X-Forwarded-For {{remote_host}}
        header_up X-Forwarded-Proto {{scheme}}
    }}
    encode gzip
    log {{
        output file /var/log/caddy/{service}-access.log
        format json
    }}
}}''',
            'api': '''
{hostname} {{
    tls {{
        dns cloudflare {{env.CLOUDFLARE_API_TOKEN}}
    }}
    reverse_proxy {ip}:{port} {{
        header_up Host {{upstream_hostport}}
        header_up X-Real-IP {{remote_host}}
        header_up X-Forwarded-For {{remote_host}}
        header_up X-Forwarded-Proto {{scheme}}
    }}
    # API-specific headers
    header {{
        Access-Control-Allow-Origin *
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, Authorization"
    }}
    encode gzip
}}''',
            'secure': '''
{hostname} {{
    tls {{
        dns cloudflare {{env.CLOUDFLARE_API_TOKEN}}
    }}
    reverse_proxy {ip}:{port} {{
        header_up Host {{upstream_hostport}}
        header_up X-Real-IP {{remote_host}}
        header_up X-Forwarded-For {{remote_host}}
        header_up X-Forwarded-Proto {{scheme}}
    }}
    # Security headers
    header {{
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Frame-Options DENY
        X-Content-Type-Options nosniff
        X-XSS-Protection "1; mode=block"
        Content-Security-Policy "default-src 'self'"
    }}
    encode gzip
}}'''
        }
        
        # NetBox headers
        self.netbox_headers = {
            'Authorization': f'Token {self.netbox_token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        # Ensure directories exist
        self.services_config_dir.mkdir(parents=True, exist_ok=True)
        self.backup_dir.mkdir(parents=True, exist_ok=True)

    def get_services_from_netbox(self) -> List[Dict]:
        """Retrieve services from NetBox with port information"""
        services = []
        try:
            # Get all IP addresses with associated services
            response = requests.get(
                f"{self.netbox_url}/api/ipam/ip-addresses/",
                headers=self.netbox_headers,
                params={'limit': 1000, 'status': 'active'}
            )
            
            if response.status_code != 200:
                logger.error(f"Failed to get IPs from NetBox: {response.status_code}")
                return services
            
            for ip_data in response.json()['results']:
                if not ip_data.get('dns_name'):
                    continue
                    
                # Extract hostname for service detection
                hostname = ip_data['dns_name']
                ip_address = ip_data['address'].split('/')[0]  # Remove CIDR
                
                # Check for custom fields indicating services
                custom_fields = ip_data.get('custom_fields', {})
                
                # Detect services based on hostname patterns and custom fields
                detected_services = self.detect_services(hostname, ip_address, custom_fields)
                
                for service in detected_services:
                    services.append({
                        'hostname': hostname,
                        'ip': ip_address,
                        'service_type': service['type'],
                        'port': service['port'],
                        'protocol': service['protocol'],
                        'custom_config': service.get('custom_config', {})
                    })
            
            logger.info(f"Retrieved {len(services)} services from NetBox")
            return services
            
        except Exception as e:
            logger.error(f"Error getting services from NetBox: {e}")
            return []

    def detect_services(self, hostname: str, ip: str, custom_fields: Dict) -> List[Dict]:
        """Detect services based on hostname patterns and custom data"""
        detected = []
        
        # Service name patterns
        service_patterns = {
            'gitlab': {'port': 80, 'type': 'web', 'protocol': 'http'},
            'git': {'port': 80, 'type': 'web', 'protocol': 'http'},
            'netbox': {'port': 8080, 'type': 'web', 'protocol': 'http'},
            'ipam': {'port': 8080, 'type': 'web', 'protocol': 'http'},
            'grafana': {'port': 3000, 'type': 'monitoring', 'protocol': 'http'},
            'prometheus': {'port': 9090, 'type': 'monitoring', 'protocol': 'http'},
            'api': {'port': 8080, 'type': 'api', 'protocol': 'http'},
            'docs': {'port': 8000, 'type': 'docs', 'protocol': 'http'},
            'admin': {'port': 8080, 'type': 'secure', 'protocol': 'http'}
        }
        
        hostname_lower = hostname.lower()
        
        # Check hostname patterns
        for pattern, config in service_patterns.items():
            if pattern in hostname_lower:
                detected.append({
                    'type': config['type'],
                    'port': config['port'],
                    'protocol': config['protocol']
                })
                break
        
        # If no pattern matched, default to web service
        if not detected:
            detected.append({
                'type': 'web',
                'port': 80,
                'protocol': 'http'
            })
        
        return detected

    def generate_service_config(self, service: Dict) -> str:
        """Generate Caddy configuration for a service"""
        service_type = service['service_type']
        template_key = 'secure' if 'admin' in service['hostname'] else service_type
        template = self.service_templates.get(template_key, self.service_templates['web'])
        
        # Prepare hostname (ensure it has domain)
        hostname = service['hostname']
        if not hostname.endswith(f'.{self.domain}'):
            if '.' not in hostname:
                hostname = f"{hostname}.{self.domain}"
        
        config = template.format(
            hostname=hostname,
            ip=service['ip'],
            port=service['port'],
            service=service['hostname'].split('.')[0]  # Service name for logging
        )
        
        return config

    def backup_current_config(self) -> str:
        """Create backup of current Caddy configuration"""
        timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
        backup_file = self.backup_dir / f"Caddyfile.backup.{timestamp}"
        
        if self.main_caddyfile.exists():
            shutil.copy2(self.main_caddyfile, backup_file)
            logger.info(f"Backed up Caddyfile to {backup_file}")
            return str(backup_file)
        
        return ""

    def generate_main_caddyfile(self, services: List[Dict]) -> str:
        """Generate the main Caddyfile with all services"""
        header = f'''# Auto-generated Caddyfile - {datetime.now().isoformat()}
# Generated by Caddy Service Manager
# DO NOT EDIT MANUALLY - Changes will be overwritten

# Global configuration
{{
    email admin@{self.domain}
    auto_https on
}}

'''
        
        service_configs = []
        
        # Generate configuration for each service
        for service in services:
            config = self.generate_service_config(service)
            service_configs.append(config)
        
        # Combine all configurations
        full_config = header + '\n'.join(service_configs)
        
        return full_config

    def validate_caddy_config(self, config_content: str) -> bool:
        """Validate Caddy configuration syntax"""
        try:
            # Write config to temporary file
            with tempfile.NamedTemporaryFile(mode='w', suffix='.caddyfile', delete=False) as temp_file:
                temp_file.write(config_content)
                temp_file_path = temp_file.name
            
            # Validate using Caddy
            result = subprocess.run(
                ['caddy', 'validate', '--config', temp_file_path],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            # Clean up temp file
            os.unlink(temp_file_path)
            
            if result.returncode == 0:
                logger.info("✅ Caddy configuration is valid")
                return True
            else:
                logger.error(f"❌ Caddy configuration validation failed: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"Error validating Caddy config: {e}")
            return False

    def reload_caddy(self) -> bool:
        """Reload Caddy with new configuration"""
        try:
            # Use Caddy API to reload configuration
            result = subprocess.run(
                ['caddy', 'reload', '--config', str(self.main_caddyfile)],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                logger.info("✅ Caddy reloaded successfully")
                return True
            else:
                logger.error(f"❌ Caddy reload failed: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"Error reloading Caddy: {e}")
            return False

    def update_caddy_configuration(self) -> bool:
        """Main method to update Caddy configuration from NetBox"""
        logger.info("🔄 Starting Caddy configuration update")
        
        # Get services from NetBox
        services = self.get_services_from_netbox()
        
        if not services:
            logger.warning("No services found in NetBox")
            return False
        
        # Generate new configuration
        new_config = self.generate_main_caddyfile(services)
        
        # Validate configuration
        if not self.validate_caddy_config(new_config):
            logger.error("Configuration validation failed, aborting update")
            return False
        
        # Backup current configuration
        backup_file = self.backup_current_config()
        
        try:
            # Write new configuration
            self.main_caddyfile.write_text(new_config)
            logger.info(f"✅ Updated Caddyfile with {len(services)} services")
            
            # Reload Caddy
            if self.reload_caddy():
                logger.info("🎉 Caddy configuration updated successfully")
                
                # Log service summary
                logger.info("📋 Configured services:")
                for service in services:
                    logger.info(f"   • {service['hostname']} -> {service['ip']}:{service['port']}")
                
                return True
            else:
                # Restore backup if reload failed
                if backup_file and Path(backup_file).exists():
                    shutil.copy2(backup_file, self.main_caddyfile)
                    logger.error("❌ Caddy reload failed, restored backup configuration")
                return False
                
        except Exception as e:
            logger.error(f"Error updating configuration: {e}")
            # Restore backup
            if backup_file and Path(backup_file).exists():
                shutil.copy2(backup_file, self.main_caddyfile)
                logger.info("Restored backup configuration after error")
            return False

    def add_service_manually(self, hostname: str, ip: str, port: int, service_type: str = 'web') -> bool:
        """Manually add a service to Caddy configuration"""
        logger.info(f"➕ Adding service manually: {hostname} -> {ip}:{port}")
        
        # Create service object
        service = {
            'hostname': hostname,
            'ip': ip,
            'port': port,
            'service_type': service_type,
            'protocol': 'http'
        }
        
        # Generate configuration for this service
        service_config = self.generate_service_config(service)
        
        # Write to individual service file
        service_file = self.services_config_dir / f"{hostname.replace('.', '_')}.caddyfile"
        service_file.write_text(service_config)
        
        # Update main configuration
        return self.update_caddy_configuration()

def main():
    """Main CLI entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Caddy Service Manager')
    parser.add_argument('--update', action='store_true', help='Update Caddy configuration from NetBox')
    parser.add_argument('--add', nargs=4, metavar=('HOSTNAME', 'IP', 'PORT', 'TYPE'), 
                       help='Manually add service: hostname ip port type')
    parser.add_argument('--validate', action='store_true', help='Validate current Caddy configuration')
    
    args = parser.parse_args()
    
    manager = CaddyServiceManager()
    
    if args.update:
        success = manager.update_caddy_configuration()
        exit(0 if success else 1)
    
    elif args.add:
        hostname, ip, port, service_type = args.add
        success = manager.add_service_manually(hostname, ip, int(port), service_type)
        exit(0 if success else 1)
    
    elif args.validate:
        if manager.main_caddyfile.exists():
            config = manager.main_caddyfile.read_text()
            valid = manager.validate_caddy_config(config)
            print("✅ Configuration is valid" if valid else "❌ Configuration is invalid")
            exit(0 if valid else 1)
        else:
            print("❌ Caddyfile not found")
            exit(1)
    
    else:
        parser.print_help()

if __name__ == "__main__":
    main()