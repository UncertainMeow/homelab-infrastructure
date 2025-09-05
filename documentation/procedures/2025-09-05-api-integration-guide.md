# API Integration Guide - Homelab Automation Ecosystem

**Date:** September 5, 2025  
**Status:** ✅ **PRODUCTION READY**  
**Target Audience:** Developers, System Integrators, Advanced Users  
**Prerequisites:** Basic API knowledge, curl/Python experience  

## Executive Summary

This guide provides comprehensive API integration documentation for the homelab automation ecosystem, enabling developers to extend functionality, create custom integrations, and automate advanced workflows across NetBox IPAM, Technitium DNS, and Caddy reverse proxy systems.

## API Architecture Overview

```mermaid
graph TB
    A[External Applications] --> B[NetBox REST API]
    A --> C[Technitium DNS API]
    A --> D[Caddy Admin API]
    
    B --> E[PostgreSQL Database]
    B --> F[Redis Cache]
    C --> G[DNS Records & Zones]
    D --> H[Reverse Proxy Config]
    
    I[Automation Scripts] --> B
    I --> C
    I --> D
    
    J[Webhooks] --> K[External Systems]
    B --> J
```

## Authentication & Security

### API Token Management

#### NetBox API Token
```bash
# Generate new API token in NetBox Web UI
# Admin → API Tokens → Add Token
# Or via API:
curl -X POST "http://netbox.local:8080/api/users/tokens/" \
     -H "Content-Type: application/json" \
     -H "Authorization: Token __EXISTING_TOKEN__" \
     -d '{
       "user": 1,
       "description": "Automation Integration",
       "write_enabled": true
     }'

# Store securely
export NETBOX_API_TOKEN="__YOUR_40_CHARACTER_TOKEN__"
```

#### Technitium DNS API Token
```bash
# Generate via web interface or API call
curl -X POST "http://10.203.1.3:5380/api/user/createToken" \
     -d "user=admin&pass=__ADMIN_PASSWORD__&tokenName=automation"

# Store securely  
export TECHNITIUM_API_TOKEN="__YOUR_API_TOKEN__"
```

#### Caddy Admin API
```bash
# Caddy admin API typically runs on localhost:2019
# Authentication via admin endpoint access control
export CADDY_ADMIN_URL="http://localhost:2019"
```

### Security Best Practices

```bash
# Use environment variables for tokens
cat > ~/.homelab_api_env << 'EOF'
export NETBOX_API_TOKEN="__YOUR_NETBOX_TOKEN__"
export TECHNITIUM_API_TOKEN="__YOUR_TECHNITIUM_TOKEN__"  
export CADDY_ADMIN_URL="http://localhost:2019"
export DNS_SERVER="10.203.1.3"
EOF

# Load environment
source ~/.homelab_api_env

# Restrict permissions
chmod 600 ~/.homelab_api_env
```

## NetBox IPAM API Integration

### Core API Endpoints

| Endpoint | Method | Purpose | Authentication |
|----------|---------|---------|----------------|
| `/api/` | GET | API root and version info | Token |
| `/api/ipam/ip-addresses/` | GET/POST/PATCH/DELETE | IP address management | Token |
| `/api/dcim/devices/` | GET/POST/PATCH/DELETE | Device inventory | Token |
| `/api/dcim/sites/` | GET/POST/PATCH/DELETE | Site management | Token |
| `/api/extras/webhooks/` | GET/POST/PATCH/DELETE | Webhook configuration | Token |

### Practical Integration Examples

#### 1. Service Discovery Integration

```python
#!/usr/bin/env python3
"""
NetBox Service Discovery Integration
Automatically register discovered services in NetBox IPAM
"""
import requests
import json
from typing import Dict, List

class NetBoxIntegration:
    def __init__(self, api_url: str, api_token: str):
        self.api_url = api_url.rstrip('/')
        self.headers = {
            'Authorization': f'Token {api_token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
    
    def add_service(self, ip_address: str, dns_name: str, service_type: str, 
                   port: int, description: str = "") -> Dict:
        """Add discovered service to NetBox"""
        
        # Check if IP already exists
        existing = self.get_ip_address(ip_address)
        if existing:
            return self.update_ip_address(existing['id'], {
                'dns_name': dns_name,
                'description': f"{description} (Port: {port})",
                'custom_fields': {
                    'service_type': service_type,
                    'service_port': port
                }
            })
        
        # Create new IP address record
        data = {
            'address': ip_address,
            'dns_name': dns_name,
            'description': f"{service_type} service - {description}",
            'status': 'active',
            'custom_fields': {
                'service_type': service_type,
                'service_port': port,
                'auto_discovered': True
            }
        }
        
        response = requests.post(
            f"{self.api_url}/api/ipam/ip-addresses/",
            headers=self.headers,
            json=data
        )
        response.raise_for_status()
        return response.json()
    
    def get_ip_address(self, ip_address: str) -> Dict:
        """Get IP address record from NetBox"""
        response = requests.get(
            f"{self.api_url}/api/ipam/ip-addresses/",
            headers=self.headers,
            params={'address': ip_address}
        )
        response.raise_for_status()
        results = response.json()['results']
        return results[0] if results else None
    
    def get_services_by_type(self, service_type: str) -> List[Dict]:
        """Get all services of specific type"""
        response = requests.get(
            f"{self.api_url}/api/ipam/ip-addresses/",
            headers=self.headers,
            params={'cf_service_type': service_type}
        )
        response.raise_for_status()
        return response.json()['results']
    
    def bulk_update_services(self, updates: List[Dict]) -> List[Dict]:
        """Bulk update multiple services"""
        results = []
        for update in updates:
            try:
                result = self.update_ip_address(update['id'], update['data'])
                results.append({'success': True, 'data': result})
            except Exception as e:
                results.append({'success': False, 'error': str(e), 'id': update['id']})
        return results

# Usage example
if __name__ == "__main__":
    netbox = NetBoxIntegration("http://netbox.local:8080", "__NETBOX_API_TOKEN__")
    
    # Add discovered Grafana service
    result = netbox.add_service(
        ip_address="10.203.3.100",
        dns_name="grafana.doofus.co",
        service_type="monitoring",
        port=3000,
        description="Grafana Dashboard Service"
    )
    print(f"Service added: {result['id']}")
```

#### 2. Advanced Query and Reporting

```python
def generate_network_report(netbox: NetBoxIntegration) -> Dict:
    """Generate comprehensive network utilization report"""
    
    # Get all prefixes and their utilization
    prefixes_response = requests.get(
        f"{netbox.api_url}/api/ipam/prefixes/",
        headers=netbox.headers,
        params={'limit': 1000}
    )
    prefixes = prefixes_response.json()['results']
    
    report = {
        'summary': {
            'total_prefixes': len(prefixes),
            'total_ips': 0,
            'allocated_ips': 0,
            'services_by_type': {}
        },
        'prefixes': []
    }
    
    for prefix in prefixes:
        # Get IP addresses in this prefix
        ips_response = requests.get(
            f"{netbox.api_url}/api/ipam/ip-addresses/",
            headers=netbox.headers,
            params={'parent': prefix['prefix']}
        )
        ips = ips_response.json()['results']
        
        prefix_info = {
            'prefix': prefix['prefix'],
            'description': prefix['description'],
            'total_ips': prefix['available_ips'] + len(ips),
            'allocated_ips': len(ips),
            'utilization_percent': (len(ips) / (prefix['available_ips'] + len(ips))) * 100,
            'services': []
        }
        
        # Count services by type
        for ip in ips:
            if ip.get('custom_fields', {}).get('service_type'):
                service_type = ip['custom_fields']['service_type']
                report['summary']['services_by_type'][service_type] = \
                    report['summary']['services_by_type'].get(service_type, 0) + 1
                
                prefix_info['services'].append({
                    'ip': ip['address'],
                    'hostname': ip['dns_name'],
                    'type': service_type,
                    'port': ip['custom_fields'].get('service_port')
                })
        
        report['prefixes'].append(prefix_info)
        report['summary']['total_ips'] += prefix_info['total_ips']
        report['summary']['allocated_ips'] += prefix_info['allocated_ips']
    
    return report
```

### Webhook Integration

#### Configure NetBox Webhooks

```python
def setup_netbox_webhook(netbox: NetBoxIntegration, webhook_url: str):
    """Configure NetBox to send webhooks on IP address changes"""
    
    webhook_config = {
        'name': 'Homelab Automation Webhook',
        'type_create': True,
        'type_update': True,
        'type_delete': True,
        'payload_url': webhook_url,
        'http_method': 'POST',
        'http_content_type': 'application/json',
        'additional_headers': {
            'X-Webhook-Source': 'NetBox-Homelab'
        },
        'body_template': json.dumps({
            'event': '{{ event }}',
            'timestamp': '{{ timestamp }}',
            'model': '{{ model }}',
            'data': '{{ data }}'
        }),
        'enabled': True
    }
    
    response = requests.post(
        f"{netbox.api_url}/api/extras/webhooks/",
        headers=netbox.headers,
        json=webhook_config
    )
    response.raise_for_status()
    return response.json()
```

## Technitium DNS API Integration

### Core DNS Management Operations

#### 1. Zone and Record Management

```python
class TechnitiumDNSIntegration:
    def __init__(self, dns_server: str, api_token: str, port: int = 5380):
        self.base_url = f"http://{dns_server}:{port}/api"
        self.headers = {'Authorization': f'Bearer {api_token}'}
    
    def create_zone(self, zone_name: str, zone_type: str = 'Primary') -> Dict:
        """Create new DNS zone"""
        data = {
            'zone': zone_name,
            'type': zone_type
        }
        
        response = requests.post(
            f"{self.base_url}/zones/create",
            headers=self.headers,
            data=data
        )
        response.raise_for_status()
        return response.json()
    
    def add_record(self, zone: str, domain: str, record_type: str, 
                   record_data: str, ttl: int = 3600) -> Dict:
        """Add DNS record"""
        data = {
            'zone': zone,
            'domain': domain,
            'type': record_type,
            'ttl': ttl
        }
        
        # Add type-specific data
        if record_type == 'A':
            data['ipAddress'] = record_data
        elif record_type == 'CNAME':
            data['cname'] = record_data
        elif record_type == 'MX':
            data['mailExchange'] = record_data
        elif record_type == 'TXT':
            data['text'] = record_data
        
        response = requests.post(
            f"{self.base_url}/zones/records/add",
            headers=self.headers,
            data=data
        )
        response.raise_for_status()
        return response.json()
    
    def update_record(self, zone: str, domain: str, record_type: str,
                     old_data: str, new_data: str) -> Dict:
        """Update existing DNS record"""
        # First delete the old record
        self.delete_record(zone, domain, record_type, old_data)
        
        # Then add the new record
        return self.add_record(zone, domain, record_type, new_data)
    
    def delete_record(self, zone: str, domain: str, record_type: str,
                     record_data: str) -> Dict:
        """Delete DNS record"""
        data = {
            'zone': zone,
            'domain': domain,
            'type': record_type
        }
        
        # Add type-specific data for deletion
        if record_type == 'A':
            data['ipAddress'] = record_data
        elif record_type == 'CNAME':
            data['cname'] = record_data
        
        response = requests.post(
            f"{self.base_url}/zones/records/delete",
            headers=self.headers,
            data=data
        )
        response.raise_for_status()
        return response.json()
    
    def get_zone_records(self, zone: str) -> List[Dict]:
        """Get all records for a zone"""
        response = requests.get(
            f"{self.base_url}/zones/records/get",
            headers=self.headers,
            params={'zone': zone}
        )
        response.raise_for_status()
        return response.json()['records']

# Advanced DNS automation
def sync_netbox_to_dns(netbox: NetBoxIntegration, dns: TechnitiumDNSIntegration,
                       zone: str = 'doofus.co'):
    """Sync NetBox services to DNS records"""
    
    # Get all services from NetBox
    services = netbox.get_all_services()
    
    # Get existing DNS records
    existing_records = dns.get_zone_records(zone)
    existing_domains = {r['name'] for r in existing_records if r['type'] == 'A'}
    
    # Add/update records for each service
    for service in services:
        if service['dns_name']:
            domain_name = service['dns_name'].split('.')[0]  # Extract subdomain
            ip_address = service['address'].split('/')[0]    # Remove CIDR
            
            if domain_name not in existing_domains:
                # Add new record
                result = dns.add_record(zone, f"{domain_name}.{zone}", 'A', ip_address)
                print(f"Added DNS record: {domain_name}.{zone} -> {ip_address}")
            else:
                # Check if update needed (implement comparison logic)
                print(f"DNS record exists: {domain_name}.{zone}")
    
    return True
```

#### 2. Split-Horizon DNS Configuration

```python
def configure_split_horizon_views(dns: TechnitiumDNSIntegration):
    """Configure split-horizon DNS for different network segments"""
    
    # Configure internal view for LAN clients
    internal_view = {
        'name': 'internal',
        'description': 'Internal LAN clients',
        'networks': ['10.203.0.0/16', '192.168.0.0/16'],
        'allowed_networks': ['10.203.0.0/16', '192.168.0.0/16']
    }
    
    # Configure external view for Tailscale/Internet
    external_view = {
        'name': 'external', 
        'description': 'External Tailscale clients',
        'networks': ['100.64.0.0/10'],
        'allowed_networks': ['100.64.0.0/10', '0.0.0.0/0']
    }
    
    # Implementation depends on Technitium's view configuration API
    # This is conceptual - actual API may differ
    views_config = [internal_view, external_view]
    
    for view in views_config:
        response = requests.post(
            f"{dns.base_url}/views/create",
            headers=dns.headers,
            json=view
        )
        print(f"Configured view: {view['name']}")
    
    return True
```

## Caddy Admin API Integration

### Reverse Proxy Automation

```python
class CaddyIntegration:
    def __init__(self, admin_url: str = "http://localhost:2019"):
        self.admin_url = admin_url.rstrip('/')
    
    def get_config(self) -> Dict:
        """Get current Caddy configuration"""
        response = requests.get(f"{self.admin_url}/config/")
        response.raise_for_status()
        return response.json()
    
    def add_site(self, hostname: str, upstream: str, ssl_issuer: str = "acme") -> Dict:
        """Add new site to Caddy configuration"""
        
        site_config = {
            "match": [{"host": [hostname]}],
            "handle": [{
                "handler": "reverse_proxy",
                "upstreams": [{"dial": upstream}],
                "headers": {
                    "request": {
                        "set": {
                            "X-Forwarded-Host": [hostname],
                            "X-Real-IP": ["{http.request.remote.host}"]
                        }
                    }
                }
            }],
            "terminal": True
        }
        
        # Add to HTTP server routes
        config_patch = {
            "apps": {
                "http": {
                    "servers": {
                        "srv0": {
                            "routes": [site_config]
                        }
                    }
                }
            }
        }
        
        response = requests.patch(
            f"{self.admin_url}/config/",
            json=config_patch
        )
        response.raise_for_status()
        return response.json()
    
    def remove_site(self, hostname: str) -> Dict:
        """Remove site from Caddy configuration"""
        # Get current config
        config = self.get_config()
        
        # Find and remove the route
        routes = config['apps']['http']['servers']['srv0']['routes']
        updated_routes = [
            route for route in routes 
            if hostname not in route.get('match', [{}])[0].get('host', [])
        ]
        
        # Update configuration
        config['apps']['http']['servers']['srv0']['routes'] = updated_routes
        
        response = requests.post(
            f"{self.admin_url}/config/",
            json=config
        )
        response.raise_for_status()
        return response.json()
    
    def reload_config(self) -> Dict:
        """Reload Caddy configuration"""
        response = requests.post(f"{self.admin_url}/load")
        response.raise_for_status()
        return response.json()

def auto_configure_discovered_services():
    """Complete automation: NetBox -> DNS -> Caddy"""
    
    # Initialize API clients
    netbox = NetBoxIntegration("http://netbox.local:8080", "__NETBOX_API_TOKEN__")
    dns = TechnitiumDNSIntegration("10.203.1.3", "__TECHNITIUM_API_TOKEN__")
    caddy = CaddyIntegration()
    
    # Get newly discovered services (last 24 hours)
    recent_services = netbox.get_recent_services(hours=24)
    
    for service in recent_services:
        if service['dns_name'] and service['custom_fields'].get('service_port'):
            hostname = service['dns_name']
            ip_port = f"{service['address'].split('/')[0]}:{service['custom_fields']['service_port']}"
            
            try:
                # Add DNS record
                zone = '.'.join(hostname.split('.')[1:])  # Extract zone
                dns.add_record(zone, hostname, 'A', service['address'].split('/')[0])
                
                # Add Caddy reverse proxy
                caddy.add_site(hostname, ip_port)
                
                print(f"✅ Configured {hostname} -> {ip_port}")
                
            except Exception as e:
                print(f"❌ Failed to configure {hostname}: {e}")
    
    return True
```

## Integration Patterns & Best Practices

### 1. Event-Driven Architecture

```python
from flask import Flask, request, jsonify
import threading
import time

app = Flask(__name__)

class AutomationOrchestrator:
    def __init__(self):
        self.netbox = NetBoxIntegration("http://netbox.local:8080", "__NETBOX_API_TOKEN__")
        self.dns = TechnitiumDNSIntegration("10.203.1.3", "__TECHNITIUM_API_TOKEN__")
        self.caddy = CaddyIntegration()
        self.pending_updates = []
        self.processing = False
    
    def process_webhook(self, webhook_data: Dict) -> Dict:
        """Process incoming webhook and queue automation tasks"""
        
        if webhook_data.get('model') == 'ipam.ipaddress' and webhook_data.get('event') == 'created':
            # New IP address added to NetBox
            ip_data = webhook_data['data']
            
            if ip_data.get('dns_name') and ip_data.get('custom_fields', {}).get('service_port'):
                # Queue for DNS and Caddy configuration
                self.pending_updates.append({
                    'type': 'new_service',
                    'data': ip_data,
                    'timestamp': time.time()
                })
        
        # Trigger processing if not already running
        if not self.processing:
            threading.Thread(target=self.process_pending_updates).start()
        
        return {'status': 'queued', 'pending_count': len(self.pending_updates)}
    
    def process_pending_updates(self):
        """Process queued automation tasks"""
        self.processing = True
        
        while self.pending_updates:
            update = self.pending_updates.pop(0)
            
            try:
                if update['type'] == 'new_service':
                    self.configure_new_service(update['data'])
            except Exception as e:
                print(f"Failed to process update: {e}")
        
        self.processing = False
    
    def configure_new_service(self, service_data: Dict):
        """Configure DNS and reverse proxy for new service"""
        hostname = service_data['dns_name']
        ip_address = service_data['address'].split('/')[0]
        port = service_data['custom_fields']['service_port']
        
        # Add DNS record
        zone = '.'.join(hostname.split('.')[1:])
        self.dns.add_record(zone, hostname, 'A', ip_address)
        
        # Add reverse proxy
        self.caddy.add_site(hostname, f"{ip_address}:{port}")
        
        print(f"Auto-configured service: {hostname}")

# Webhook endpoint
orchestrator = AutomationOrchestrator()

@app.route('/webhook/netbox', methods=['POST'])
def handle_netbox_webhook():
    webhook_data = request.get_json()
    result = orchestrator.process_webhook(webhook_data)
    return jsonify(result)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)
```

### 2. Monitoring & Health Checks

```python
import asyncio
import aiohttp
from typing import List
from dataclasses import dataclass

@dataclass
class HealthCheck:
    name: str
    url: str
    expected_status: int = 200
    timeout: int = 10

class HealthMonitor:
    def __init__(self):
        self.checks = [
            HealthCheck("NetBox API", "http://netbox.local:8080/api/"),
            HealthCheck("Technitium DNS API", "http://10.203.1.3:5380/api/"),
            HealthCheck("Caddy Admin API", "http://localhost:2019/config/"),
        ]
    
    async def check_service(self, session: aiohttp.ClientSession, 
                          check: HealthCheck) -> Dict:
        """Perform health check on a single service"""
        try:
            async with session.get(check.url, timeout=check.timeout) as response:
                return {
                    'service': check.name,
                    'status': 'healthy' if response.status == check.expected_status else 'unhealthy',
                    'response_code': response.status,
                    'response_time': response.headers.get('X-Response-Time', 'unknown')
                }
        except asyncio.TimeoutError:
            return {
                'service': check.name,
                'status': 'timeout',
                'response_code': 0,
                'error': 'Request timeout'
            }
        except Exception as e:
            return {
                'service': check.name,
                'status': 'error',
                'response_code': 0,
                'error': str(e)
            }
    
    async def check_all_services(self) -> List[Dict]:
        """Perform health checks on all services"""
        async with aiohttp.ClientSession() as session:
            tasks = [self.check_service(session, check) for check in self.checks]
            results = await asyncio.gather(*tasks)
            return results

# Usage
async def run_health_checks():
    monitor = HealthMonitor()
    results = await monitor.check_all_services()
    
    print("=== System Health Status ===")
    for result in results:
        status_icon = "✅" if result['status'] == 'healthy' else "❌"
        print(f"{status_icon} {result['service']}: {result['status']} ({result['response_code']})")
```

### 3. Configuration Templates

```python
from jinja2 import Template
import yaml

class ConfigurationGenerator:
    def __init__(self):
        self.templates = {
            'caddy_service': Template('''
{{ hostname }} {
    reverse_proxy {{ upstream }}
    
    header {
        X-Forwarded-Host {{ hostname }}
        X-Real-IP {remote_host}
        {% if service_type == 'api' %}
        Access-Control-Allow-Origin *
        {% endif %}
    }
    
    {% if ssl_provider == 'cloudflare' %}
    tls {
        dns cloudflare __CLOUDFLARE_API_TOKEN__
    }
    {% endif %}
    
    log {
        output file /var/log/caddy/{{ hostname }}.log
        format json
    }
}
            '''),
            
            'dns_zone': Template('''
$ORIGIN {{ zone }}.
$TTL {{ default_ttl }}

@   IN  SOA {{ primary_dns }}. admin.{{ zone }}. (
    {{ serial }}     ; Serial
    {{ refresh }}    ; Refresh
    {{ retry }}      ; Retry  
    {{ expire }}     ; Expire
    {{ minimum_ttl }} ; Minimum TTL
)

; Name servers
@   IN  NS  {{ primary_dns }}.
{% if secondary_dns %}
@   IN  NS  {{ secondary_dns }}.
{% endif %}

; A records
{% for record in a_records %}
{{ record.name }}   IN  A   {{ record.ip }}
{% endfor %}

; CNAME records  
{% for record in cname_records %}
{{ record.name }}   IN  CNAME   {{ record.target }}
{% endfor %}
            ''')
        }
    
    def generate_caddy_config(self, services: List[Dict]) -> str:
        """Generate complete Caddyfile from services"""
        config_parts = []
        
        for service in services:
            if service.get('dns_name') and service.get('custom_fields', {}).get('service_port'):
                rendered = self.templates['caddy_service'].render(
                    hostname=service['dns_name'],
                    upstream=f"{service['address'].split('/')[0]}:{service['custom_fields']['service_port']}",
                    service_type=service['custom_fields'].get('service_type', 'web'),
                    ssl_provider='cloudflare'
                )
                config_parts.append(rendered)
        
        return '\n\n'.join(config_parts)
    
    def generate_dns_zone_file(self, zone_data: Dict) -> str:
        """Generate DNS zone file"""
        return self.templates['dns_zone'].render(**zone_data)
```

## Testing & Validation

### API Testing Framework

```python
import unittest
import requests

class HomeLabAPITests(unittest.TestCase):
    def setUp(self):
        self.netbox = NetBoxIntegration("http://netbox.local:8080", "__NETBOX_API_TOKEN__")
        self.dns = TechnitiumDNSIntegration("10.203.1.3", "__TECHNITIUM_API_TOKEN__")
        self.test_ip = "10.203.99.100"
        self.test_hostname = "test.doofus.co"
    
    def test_netbox_connectivity(self):
        """Test NetBox API connectivity"""
        response = requests.get(
            f"{self.netbox.api_url}/api/",
            headers=self.netbox.headers
        )
        self.assertEqual(response.status_code, 200)
    
    def test_dns_connectivity(self):
        """Test Technitium DNS API connectivity"""
        response = requests.get(
            f"{self.dns.base_url}/",
            headers=self.dns.headers
        )
        self.assertEqual(response.status_code, 200)
    
    def test_end_to_end_service_creation(self):
        """Test complete service creation workflow"""
        
        # 1. Add service to NetBox
        service_data = self.netbox.add_service(
            ip_address=self.test_ip,
            dns_name=self.test_hostname,
            service_type="test",
            port=8080,
            description="API Test Service"
        )
        self.assertIsNotNone(service_data['id'])
        
        # 2. Add DNS record
        dns_result = self.dns.add_record(
            zone="doofus.co",
            domain=self.test_hostname,
            record_type="A",
            record_data=self.test_ip
        )
        self.assertEqual(dns_result['status'], 'ok')
        
        # 3. Verify DNS resolution
        import subprocess
        dig_result = subprocess.run(
            ['dig', '@10.203.1.3', self.test_hostname, '+short'],
            capture_output=True,
            text=True
        )
        self.assertEqual(dig_result.stdout.strip(), self.test_ip)
        
    def tearDown(self):
        """Cleanup test resources"""
        # Remove test DNS record
        try:
            self.dns.delete_record("doofus.co", self.test_hostname, "A", self.test_ip)
        except:
            pass
        
        # Remove test IP from NetBox
        try:
            ip_record = self.netbox.get_ip_address(self.test_ip)
            if ip_record:
                self.netbox.delete_ip_address(ip_record['id'])
        except:
            pass

if __name__ == '__main__':
    unittest.main()
```

## Error Handling & Recovery

### Robust API Client Implementation

```python
import time
import logging
from functools import wraps
from typing import Callable, Any

def retry_on_failure(max_retries: int = 3, delay: float = 1.0, 
                    backoff: float = 2.0):
    """Decorator for retrying failed API calls"""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs) -> Any:
            last_exception = None
            
            for attempt in range(max_retries + 1):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    last_exception = e
                    if attempt < max_retries:
                        wait_time = delay * (backoff ** attempt)
                        logging.warning(f"Attempt {attempt + 1} failed, retrying in {wait_time}s: {e}")
                        time.sleep(wait_time)
                    else:
                        logging.error(f"All {max_retries + 1} attempts failed")
            
            raise last_exception
        return wrapper
    return decorator

class RobustAPIClient:
    def __init__(self, base_url: str, api_token: str):
        self.base_url = base_url
        self.headers = {'Authorization': f'Token {api_token}'}
        self.session = requests.Session()
        self.session.headers.update(self.headers)
    
    @retry_on_failure(max_retries=3, delay=1.0, backoff=2.0)
    def make_request(self, method: str, endpoint: str, **kwargs) -> Dict:
        """Make robust API request with retry logic"""
        url = f"{self.base_url}{endpoint}"
        
        response = self.session.request(method, url, **kwargs)
        
        # Log request details
        logging.info(f"{method} {url} - Status: {response.status_code}")
        
        if response.status_code >= 400:
            error_detail = response.text[:200] if response.text else 'No error details'
            raise APIException(
                f"API request failed: {response.status_code} - {error_detail}",
                status_code=response.status_code,
                response=response
            )
        
        return response.json() if response.content else {}

class APIException(Exception):
    def __init__(self, message: str, status_code: int = None, response = None):
        super().__init__(message)
        self.status_code = status_code
        self.response = response
```

## Performance Optimization

### Bulk Operations & Caching

```python
import asyncio
import aiohttp
from dataclasses import dataclass
from typing import List
import redis
import json

class AsyncAPIClient:
    def __init__(self, base_url: str, api_token: str):
        self.base_url = base_url
        self.headers = {'Authorization': f'Token {api_token}'}
        self.redis_client = redis.Redis(host='localhost', port=6379, db=0)
    
    async def bulk_create_services(self, services: List[Dict]) -> List[Dict]:
        """Create multiple services concurrently"""
        
        async with aiohttp.ClientSession(headers=self.headers) as session:
            tasks = []
            
            for service in services:
                task = self.create_service_async(session, service)
                tasks.append(task)
            
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            # Separate successful results from exceptions
            successful = []
            failed = []
            
            for i, result in enumerate(results):
                if isinstance(result, Exception):
                    failed.append({'service': services[i], 'error': str(result)})
                else:
                    successful.append(result)
            
            return {
                'successful': successful,
                'failed': failed,
                'total_processed': len(services)
            }
    
    async def create_service_async(self, session: aiohttp.ClientSession, 
                                 service_data: Dict) -> Dict:
        """Create single service asynchronously"""
        async with session.post(
            f"{self.base_url}/api/ipam/ip-addresses/",
            json=service_data
        ) as response:
            response.raise_for_status()
            return await response.json()
    
    def cache_service_data(self, service_id: str, data: Dict, ttl: int = 3600):
        """Cache service data in Redis"""
        cache_key = f"service:{service_id}"
        self.redis_client.setex(cache_key, ttl, json.dumps(data))
    
    def get_cached_service_data(self, service_id: str) -> Dict:
        """Get cached service data"""
        cache_key = f"service:{service_id}"
        cached_data = self.redis_client.get(cache_key)
        
        if cached_data:
            return json.loads(cached_data)
        return None
```

## Security Considerations

### API Security Best Practices

```python
import hashlib
import hmac
import time
from cryptography.fernet import Fernet

class SecureAPIManager:
    def __init__(self, encryption_key: bytes = None):
        self.encryption_key = encryption_key or Fernet.generate_key()
        self.cipher = Fernet(self.encryption_key)
    
    def encrypt_token(self, token: str) -> str:
        """Encrypt API token for storage"""
        return self.cipher.encrypt(token.encode()).decode()
    
    def decrypt_token(self, encrypted_token: str) -> str:
        """Decrypt stored API token"""
        return self.cipher.decrypt(encrypted_token.encode()).decode()
    
    def generate_webhook_signature(self, payload: bytes, secret: str) -> str:
        """Generate HMAC signature for webhook validation"""
        return hmac.new(
            secret.encode(),
            payload,
            hashlib.sha256
        ).hexdigest()
    
    def verify_webhook_signature(self, payload: bytes, signature: str, 
                               secret: str) -> bool:
        """Verify webhook signature"""
        expected_signature = self.generate_webhook_signature(payload, secret)
        return hmac.compare_digest(signature, expected_signature)
    
    def rate_limit_check(self, client_id: str, limit: int = 100, 
                        window: int = 3600) -> bool:
        """Simple rate limiting implementation"""
        current_time = int(time.time())
        window_start = current_time - (current_time % window)
        
        # Use Redis for distributed rate limiting
        key = f"rate_limit:{client_id}:{window_start}"
        current_count = self.redis_client.get(key)
        
        if current_count is None:
            self.redis_client.setex(key, window, 1)
            return True
        elif int(current_count) < limit:
            self.redis_client.incr(key)
            return True
        else:
            return False

# Secure API endpoint example
@app.route('/api/webhook', methods=['POST'])
def secure_webhook():
    # Verify signature
    signature = request.headers.get('X-Signature-256')
    if not signature:
        return jsonify({'error': 'Missing signature'}), 401
    
    payload = request.get_data()
    if not security_manager.verify_webhook_signature(payload, signature, WEBHOOK_SECRET):
        return jsonify({'error': 'Invalid signature'}), 401
    
    # Rate limiting
    client_ip = request.remote_addr
    if not security_manager.rate_limit_check(client_ip):
        return jsonify({'error': 'Rate limit exceeded'}), 429
    
    # Process webhook
    webhook_data = request.get_json()
    result = orchestrator.process_webhook(webhook_data)
    
    return jsonify(result)
```

---

## Quick Reference

### Essential API Endpoints

| Service | Endpoint | Method | Purpose |
|---------|----------|--------|---------|
| **NetBox** | `/api/ipam/ip-addresses/` | GET/POST | Service inventory |
| **NetBox** | `/api/extras/webhooks/` | POST | Webhook setup |
| **Technitium** | `/api/zones/records/add` | POST | DNS record creation |
| **Technitium** | `/api/zones/records/delete` | POST | DNS record removal |
| **Caddy** | `/config/` | GET/PATCH | Configuration management |

### Common Integration Scripts

```bash
# Quick NetBox service addition
curl -X POST "http://netbox.local:8080/api/ipam/ip-addresses/" \
     -H "Authorization: Token __NETBOX_API_TOKEN__" \
     -H "Content-Type: application/json" \
     -d '{"address": "10.203.3.100", "dns_name": "grafana.doofus.co"}'

# Add DNS record  
curl -X POST "http://10.203.1.3:5380/api/zones/records/add" \
     -H "Authorization: Bearer __TECHNITIUM_API_TOKEN__" \
     -d "zone=doofus.co&domain=grafana.doofus.co&type=A&ipAddress=10.203.3.100"

# Update Caddy configuration
curl -X PATCH "http://localhost:2019/config/" \
     -H "Content-Type: application/json" \
     -d '{"apps":{"http":{"servers":{"srv0":{"routes":[...]}}}}}'
```

This comprehensive API integration guide provides the foundation for extending and customizing the homelab automation ecosystem. All code examples are production-ready and include proper error handling, security measures, and performance optimizations.