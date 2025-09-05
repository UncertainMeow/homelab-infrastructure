# Technitium DNS Dark Mode Implementation

## Quick Reference
- **Status**: Active
- **Dependencies**: Technitium DNS Server, Proxmox VE
- **Secrets Required**: None
- **Stateful Variables**: `__TECHNITIUM_HOST_IP__`, `__CONTAINER_ID__`

## Overview
Implementation of a custom dark theme for Technitium DNS Server to improve usability during nighttime operations and reduce eye strain.

## Environment Details
- **Platform**: Proxmox VE LXC Container
- **Host**: `__TECHNITIUM_HOST_IP__:5380`
- **Installation Method**: Community Scripts (helper-scripts.com)
- **Technitium Version**: Latest (installed via community script)
- **Installation Command Used**: 
  ```bash
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/technitiumdns.sh)"
  ```

## Problem Statement
Technitium DNS Server's default interface uses a bright white theme that causes eye strain during nighttime administration. While a community-created dark mode CSS existed, it required security review and proper implementation.

## Security Analysis
### Original Reddit Solution Review
- **Source**: Reddit user collaboration with Claude
- **URL**: https://pastebin.com/5TiC7jV5
- **Security Assessment**: SAFE
  - Pure CSS only (no JavaScript or executable code)
  - No external resource requests
  - No data access capabilities
  - Completely reversible

### Identified Issues with Original CSS
1. **Layout Breaking**: Rules like `.container .page { display: none !important; }` hid essential content
2. **jQuery Conflicts**: Overly aggressive CSS caused 404 errors for JavaScript resources
3. **Maintenance**: Redundant and poorly organized rules

## Implementation Process

### Phase 1: Initial Setup
1. **Created CSS file**:
   ```bash
   sudo nano /opt/technitium/dns/www/css/main-dark.css
   ```

2. **Modified HTML to include CSS**:
   - File: `/opt/technitium/dns/www/index.html`
   - Added after line 39: `<link href="css/main-dark.css" rel="stylesheet">`

3. **Service management**:
   ```bash
   sudo systemctl restart technitium.service
   ```

### Phase 2: Troubleshooting
**Issue**: Interface loaded with dark background but no content visible
**Root Cause**: CSS rules hiding essential page elements
**Error**: jQuery 404 errors preventing proper page functionality

**Diagnostic Commands**:
```bash
# Find service name
sudo systemctl list-units --type=service | grep -i technitium

# Check file structure
ls -la /opt/technitium/dns/www/js/

# Verify HTML changes
grep -n "main-dark.css" /opt/technitium/dns/www/index.html
```

### Phase 3: CSS Optimization
Created refined CSS that:
- Preserves original layout and functionality
- Focuses on color scheme changes only
- Removes problematic display and positioning overrides
- Maintains accessibility standards

## File Locations

### Primary Files Modified
```
/opt/technitium/dns/www/index.html (line 40)
/opt/technitium/dns/www/css/main-dark.css (new file)
```

### Backup Files Created
```
/opt/technitium/dns/www/index.html.backup
```

## Configuration Files
- [CSS Template](../configs/templates/technitium/main-dark.css)
- [HTML Modification Template](../configs/templates/technitium/index.html.patch)

## CSS Implementation Details

### Color Scheme Variables
```css
:root {
  --dark-bg-primary: #181a1b;     /* Main background */
  --dark-bg-secondary: #23272a;   /* Content areas */
  --dark-bg-tertiary: #2d323a;    /* Form elements */
  --dark-bg-header: #222c3c;      /* Header/navigation */
  --dark-text-primary: #e0e0e0;   /* Main text */
  --dark-text-secondary: #b0b0b0; /* Secondary text */
  --dark-text-white: #ffffff;     /* High contrast text */
  --dark-border: #444;            /* Borders */
  --link-color: #60aaff;          /* Links */
  --link-hover: #a5d6ff;          /* Link hover state */
}
```

### Key Components Styled
- Base HTML/body background
- Header and navigation elements
- Forms and input elements
- Tables and data displays
- Buttons and interactive elements
- Statistics panels with color-coded data
- Modal dialogs and dropdowns

## Troubleshooting Guide

### Common Issues

#### 1. Dark theme not loading
```bash
# Check if CSS file exists
ls -la /opt/technitium/dns/www/css/main-dark.css

# Verify HTML reference
grep "main-dark.css" /opt/technitium/dns/www/index.html

# Clear browser cache
# Use Cmd+Shift+R (Mac) or Ctrl+F5 (PC)
```

#### 2. Interface showing dark background but no content
**Cause**: CSS hiding page elements
**Solution**: Replace CSS with optimized version

#### 3. JavaScript/jQuery 404 errors
**Cause**: Aggressive CSS rules interfering with page loading
**Solution**: 
1. Temporarily disable CSS
2. Restart service
3. Implement refined CSS version

### Service Management
```bash
# Restart Technitium service
sudo systemctl restart technitium.service

# Check service status
sudo systemctl status technitium.service

# View service logs
sudo journalctl -u technitium.service -f
```

## Maintenance Procedures

### Updating Technitium
When updating Technitium DNS Server:
1. Backup custom files:
   ```bash
   cp /opt/technitium/dns/www/index.html /opt/technitium/dns/www/index.html.backup
   cp /opt/technitium/dns/www/css/main-dark.css /opt/technitium/dns/www/css/main-dark.css.backup
   ```

2. After update, verify HTML reference still exists:
   ```bash
   grep "main-dark.css" /opt/technitium/dns/www/index.html
   ```

3. If missing, re-add the CSS reference to line 40 of index.html

### Customizing Colors
To modify the color scheme:
1. Edit CSS variables in `/opt/technitium/dns/www/css/main-dark.css`
2. Test changes by refreshing browser
3. No service restart required for CSS-only changes

## Rollback Procedures

### Complete Removal
```bash
# Remove CSS file
sudo rm /opt/technitium/dns/www/css/main-dark.css

# Remove HTML reference
sudo nano /opt/technitium/dns/www/index.html
# Delete line: <link href="css/main-dark.css" rel="stylesheet">

# Restart service
sudo systemctl restart technitium.service
```

### Restore from Backup
```bash
# Restore original HTML
sudo cp /opt/technitium/dns/www/index.html.backup /opt/technitium/dns/www/index.html

# Restart service
sudo systemctl restart technitium.service
```

## Success Criteria
- ✅ Dark theme loads without errors
- ✅ All interface elements remain functional
- ✅ Statistics and charts display correctly
- ✅ No JavaScript console errors
- ✅ Responsive design maintained
- ✅ Accessibility preserved

## Future Enhancements
1. **Theme Toggle**: Implement JavaScript-based theme switcher
2. **Multiple Themes**: Create additional color scheme variants
3. **User Preferences**: Store theme choice in browser localStorage
4. **Print Styles**: Add print-friendly CSS rules

## Related Documentation
- [Technitium DNS Official Documentation](https://technitium.com/dns/)
- [Proxmox Community Scripts](https://community-scripts.github.io/ProxmoxVE/)
- [Original Reddit Discussion](https://www.reddit.com/r/technitium/comments/1g0zi6j/dark_mode/)

## Change Log
| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-09-05 | 1.0 | Homelab Admin | Initial implementation with community CSS |
| 2025-09-05 | 1.1 | Homelab Admin | Fixed layout issues, optimized CSS rules |

---
*Documentation template for homelab infrastructure management*