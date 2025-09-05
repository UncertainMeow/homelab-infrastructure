#!/bin/bash
# Create new documentation from template

if [ $# -eq 0 ]; then
    echo "Usage: $0 <service-name>"
    echo "Example: $0 nextcloud"
    exit 1
fi

SERVICE_NAME=$1
DATE=$(date +%Y-%m-%d)
FILENAME="documentation/services/${DATE}-${SERVICE_NAME}-implementation.md"

cat > "$FILENAME" << TEMPLATE
# ${SERVICE_NAME^} Implementation

## Quick Reference
- **Status**: [Planning/Testing/Active/Deprecated]
- **Dependencies**: []
- **Secrets Required**: []
- **Stateful Variables**: []

## Overview
[What is being implemented and why]

## Environment Details
- **Platform**: __PLATFORM__
- **Host**: __HOST_IP__:__PORT__
- **Version**: [specific version]

## Security Analysis
[Security review of any third-party components]

## Implementation Process
[Step-by-step implementation]

## Configuration Files
[Links to template files in configs/templates/]

## Troubleshooting
[Common issues and solutions]

## Rollback Procedures
[How to undo changes]

## Maintenance
[Ongoing maintenance requirements]

## Change Log
| Date | Version | Author | Changes |
|------|---------|--------|---------|
| ${DATE} | 1.0 | Homelab Admin | Initial implementation |
TEMPLATE

echo "Created template: $FILENAME"
echo "Edit the file and commit when ready"
