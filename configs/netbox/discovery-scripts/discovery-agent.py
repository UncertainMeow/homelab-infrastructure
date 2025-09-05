#!/usr/bin/env python3
"""
NetBox Network Discovery Agent
Automatically discovers network devices and integrates with DNS and IPAM
"""

import os
import time
import json
import logging
import schedule
import requests
import nmap
import dns.resolver
import dns.reversename
from datetime import datetime, timedelta
from netaddr import IPNetwork, IPAddress
from typing import Dict, List, Optional, Any

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/logs/discovery.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class NetBoxDiscoveryAgent:
    def __init__(self):
        self.netbox_url = os.getenv('NETBOX_URL', 'http://netbox:8080')
        self.netbox_token = os.getenv('NETBOX_TOKEN')
        self.dns_server = os.getenv('DNS_SERVER', '10.203.1.3')
        self.discovery_networks = os.getenv('DISCOVERY_NETWORKS', '10.203.0.0/16').split(',')
        self.technitium_server = os.getenv('TECHNITIUM_SERVER', '10.203.1.3:5380')
        self.technitium_token = os.getenv('TECHNITIUM_API_TOKEN')
        
        # Initialize NetBox API headers
        self.headers = {
            'Authorization': f'Token {self.netbox_token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        # Initialize nmap scanner
        self.nm = nmap.PortScanner()
        
        logger.info(f"Initialized NetBox Discovery Agent")
        logger.info(f"NetBox URL: {self.netbox_url}")
        logger.info(f"Discovery Networks: {self.discovery_networks}")

    def test_netbox_connection(self) -> bool:
        """Test connection to NetBox API"""
        try:
            response = requests.get(f"{self.netbox_url}/api/", headers=self.headers, timeout=10)
            if response.status_code == 200:
                logger.info("✅ NetBox API connection successful")
                return True
            else:
                logger.error(f"❌ NetBox API returned status {response.status_code}")
                return False
        except Exception as e:
            logger.error(f"❌ Failed to connect to NetBox API: {e}")
            return False

    def get_or_create_site(self, name: str = "Homelab") -> Dict:
        """Get or create a site in NetBox"""
        try:
            # Check if site exists
            response = requests.get(
                f"{self.netbox_url}/api/dcim/sites/",
                headers=self.headers,
                params={'name': name}
            )
            
            if response.status_code == 200 and response.json()['count'] > 0:
                return response.json()['results'][0]
            
            # Create new site
            site_data = {
                'name': name,
                'slug': name.lower(),
                'description': f'Auto-discovered {name} site',
                'status': 'active'
            }
            
            response = requests.post(
                f"{self.netbox_url}/api/dcim/sites/",
                headers=self.headers,
                data=json.dumps(site_data)
            )
            
            if response.status_code == 201:
                logger.info(f"✅ Created site: {name}")
                return response.json()
            else:
                logger.error(f"❌ Failed to create site: {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"❌ Error handling site: {e}")
            return None

    def get_or_create_prefix(self, prefix: str, site_id: int) -> Dict:
        """Get or create a prefix in NetBox"""
        try:
            # Check if prefix exists
            response = requests.get(
                f"{self.netbox_url}/api/ipam/prefixes/",
                headers=self.headers,
                params={'prefix': prefix}
            )
            
            if response.status_code == 200 and response.json()['count'] > 0:
                return response.json()['results'][0]
            
            # Create new prefix
            prefix_data = {
                'prefix': prefix,
                'site': site_id,
                'description': f'Auto-discovered network prefix {prefix}',
                'status': 'active',
                'is_pool': True
            }
            
            response = requests.post(
                f"{self.netbox_url}/api/ipam/prefixes/",
                headers=self.headers,
                data=json.dumps(prefix_data)
            )
            
            if response.status_code == 201:
                logger.info(f"✅ Created prefix: {prefix}")
                return response.json()
            else:
                logger.error(f"❌ Failed to create prefix: {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"❌ Error handling prefix: {e}")
            return None

    def perform_network_scan(self, network: str) -> List[Dict]:
        """Perform network scan and return discovered hosts"""
        logger.info(f"🔍 Scanning network: {network}")
        discovered_hosts = []
        
        try:
            # Perform ping scan with service detection
            scan_result = self.nm.scan(
                hosts=network,
                arguments='-sn -PE -PP -PS80,443,22,53 --max-retries=2 --host-timeout=30s'
            )
            
            for host in self.nm.all_hosts():
                if self.nm[host].state() == 'up':
                    host_info = {
                        'ip': host,
                        'hostname': None,
                        'mac_address': None,
                        'vendor': None,
                        'last_seen': datetime.now().isoformat(),
                        'services': []
                    }
                    
                    # Get hostname via reverse DNS
                    try:
                        hostname = dns.resolver.resolve(dns.reversename.from_address(host), 'PTR')[0].to_text().rstrip('.')
                        host_info['hostname'] = hostname
                    except:
                        pass
                    
                    # Get MAC address if available
                    if 'mac' in self.nm[host]['addresses']:
                        host_info['mac_address'] = self.nm[host]['addresses']['mac']
                        
                        # Try to get vendor from MAC
                        try:
                            vendor_response = requests.get(f"https://api.macvendors.com/{host_info['mac_address']}", timeout=5)
                            if vendor_response.status_code == 200:
                                host_info['vendor'] = vendor_response.text
                        except:
                            pass
                    
                    discovered_hosts.append(host_info)
                    logger.info(f"📍 Found host: {host} ({host_info.get('hostname', 'Unknown')})")
            
            logger.info(f"✅ Network scan complete: {len(discovered_hosts)} hosts discovered")
            return discovered_hosts
            
        except Exception as e:
            logger.error(f"❌ Network scan failed: {e}")
            return []

    def perform_service_scan(self, ip: str) -> List[Dict]:
        """Perform detailed service scan on a host"""
        services = []
        try:
            # Scan common ports
            scan_result = self.nm.scan(
                hosts=ip,
                ports='22,53,80,443,5380,8080,9000,3000,5432,6379,27017',
                arguments='-sV --max-retries=1 --host-timeout=10s'
            )
            
            if ip in self.nm.all_hosts():
                for protocol in self.nm[ip].all_protocols():
                    ports = self.nm[ip][protocol].keys()
                    for port in ports:
                        port_info = self.nm[ip][protocol][port]
                        if port_info['state'] == 'open':
                            service = {
                                'port': port,
                                'protocol': protocol,
                                'service': port_info.get('name', 'unknown'),
                                'version': port_info.get('version', ''),
                                'product': port_info.get('product', '')
                            }
                            services.append(service)
            
        except Exception as e:
            logger.debug(f"Service scan failed for {ip}: {e}")
        
        return services

    def update_netbox_ip(self, ip_data: Dict) -> bool:
        """Update or create IP address in NetBox"""
        try:
            ip_address = ip_data['ip']
            
            # Check if IP exists
            response = requests.get(
                f"{self.netbox_url}/api/ipam/ip-addresses/",
                headers=self.headers,
                params={'address': ip_address}
            )
            
            netbox_data = {
                'address': ip_address,
                'status': 'active',
                'description': f"Auto-discovered on {ip_data['last_seen'][:10]}",
                'custom_fields': {
                    'last_seen': ip_data['last_seen'],
                    'discovery_method': 'network_scan'
                }
            }
            
            if ip_data.get('hostname'):
                netbox_data['dns_name'] = ip_data['hostname']
            
            if response.status_code == 200 and response.json()['count'] > 0:
                # Update existing IP
                ip_id = response.json()['results'][0]['id']
                response = requests.patch(
                    f"{self.netbox_url}/api/ipam/ip-addresses/{ip_id}/",
                    headers=self.headers,
                    data=json.dumps(netbox_data)
                )
                action = "Updated"
            else:
                # Create new IP
                response = requests.post(
                    f"{self.netbox_url}/api/ipam/ip-addresses/",
                    headers=self.headers,
                    data=json.dumps(netbox_data)
                )
                action = "Created"
            
            if response.status_code in [200, 201]:
                logger.debug(f"✅ {action} IP in NetBox: {ip_address}")
                return True
            else:
                logger.error(f"❌ Failed to update NetBox IP {ip_address}: {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"❌ Error updating NetBox IP: {e}")
            return False

    def sync_to_dns(self, ip_data: Dict) -> bool:
        """Sync discovered host to DNS server"""
        if not self.technitium_token or not ip_data.get('hostname'):
            return False
            
        try:
            # Add/update A record in Technitium DNS
            dns_data = {
                'zone': 'doofus.co',
                'domain': f"{ip_data['hostname'].split('.')[0]}.doofus.co",
                'type': 'A',
                'ipAddress': ip_data['ip'],
                'ttl': 300
            }
            
            response = requests.post(
                f"http://{self.technitium_server}/api/zones/records/add",
                headers={'Authorization': f'Bearer {self.technitium_token}'},
                data=dns_data
            )
            
            if response.status_code == 200:
                logger.info(f"✅ Synced to DNS: {dns_data['domain']} -> {ip_data['ip']}")
                return True
            else:
                logger.debug(f"DNS sync failed for {ip_data['hostname']}: {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"❌ DNS sync error: {e}")
            return False

    def generate_network_report(self) -> Dict:
        """Generate comprehensive network report"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'networks_scanned': self.discovery_networks,
            'total_hosts': 0,
            'active_hosts': 0,
            'new_hosts': 0,
            'updated_hosts': 0,
            'dns_synced': 0,
            'services_discovered': 0
        }
        
        return report

    def run_discovery(self) -> Dict:
        """Main discovery process"""
        logger.info("🚀 Starting network discovery process")
        start_time = datetime.now()
        
        # Test connections
        if not self.test_netbox_connection():
            logger.error("❌ Cannot proceed without NetBox connection")
            return {'status': 'failed', 'reason': 'netbox_connection_failed'}
        
        # Ensure site exists
        site = self.get_or_create_site("Homelab")
        if not site:
            logger.error("❌ Failed to create/get site")
            return {'status': 'failed', 'reason': 'site_creation_failed'}
        
        report = self.generate_network_report()
        
        # Process each network
        for network in self.discovery_networks:
            network = network.strip()
            logger.info(f"🌐 Processing network: {network}")
            
            # Ensure prefix exists in NetBox
            prefix = self.get_or_create_prefix(network, site['id'])
            
            # Discover hosts
            discovered_hosts = self.perform_network_scan(network)
            
            for host in discovered_hosts:
                report['total_hosts'] += 1
                
                # Perform detailed service scan for interesting hosts
                if any(port in str(host['ip']) for port in ['1', '3', '10']):  # Gateway/server IPs
                    host['services'] = self.perform_service_scan(host['ip'])
                    report['services_discovered'] += len(host['services'])
                
                # Update NetBox
                if self.update_netbox_ip(host):
                    report['updated_hosts'] += 1
                
                # Sync to DNS if hostname available
                if self.sync_to_dns(host):
                    report['dns_synced'] += 1
                
                report['active_hosts'] += 1
        
        # Calculate duration
        duration = datetime.now() - start_time
        report['duration_seconds'] = duration.total_seconds()
        report['status'] = 'completed'
        
        logger.info(f"✅ Discovery completed in {duration.total_seconds():.1f}s")
        logger.info(f"📊 Stats: {report['active_hosts']} active hosts, {report['dns_synced']} DNS synced")
        
        return report

    def export_to_file(self, data: Dict, filename: str) -> bool:
        """Export data to JSON file"""
        try:
            os.makedirs('/app/exports', exist_ok=True)
            filepath = f"/app/exports/{filename}"
            
            with open(filepath, 'w') as f:
                json.dump(data, f, indent=2, default=str)
            
            logger.info(f"✅ Data exported to {filepath}")
            return True
        except Exception as e:
            logger.error(f"❌ Export failed: {e}")
            return False

def main():
    """Main application entry point"""
    # Ensure log directory exists
    os.makedirs('/app/logs', exist_ok=True)
    os.makedirs('/app/exports', exist_ok=True)
    
    agent = NetBoxDiscoveryAgent()
    
    # Run initial discovery
    logger.info("🎯 Running initial network discovery")
    report = agent.run_discovery()
    agent.export_to_file(report, f"discovery-report-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json")
    
    # Schedule regular discovery runs
    schedule.every(30).minutes.do(agent.run_discovery)
    schedule.every(1).hour.do(lambda: agent.export_to_file(
        agent.run_discovery(),
        f"discovery-report-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json"
    ))
    
    logger.info("⏰ Scheduled discovery: every 30 minutes")
    logger.info("📁 Data exports: every hour")
    
    # Keep running
    try:
        while True:
            schedule.run_pending()
            time.sleep(60)
    except KeyboardInterrupt:
        logger.info("🛑 Discovery agent stopped by user")
    except Exception as e:
        logger.error(f"❌ Discovery agent crashed: {e}")
        raise

if __name__ == "__main__":
    main()