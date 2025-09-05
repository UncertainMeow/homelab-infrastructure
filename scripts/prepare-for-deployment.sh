#!/bin/bash
# Helper script for replacing template variables

echo "=== Template Variable Replacement Helper ==="
echo "This script helps identify variables that need replacement before deployment"
echo ""

if [ $# -eq 0 ]; then
    echo "Usage: $0 <template-file>"
    echo "Example: $0 configs/templates/technitium/main-dark.css"
    exit 1
fi

TEMPLATE_FILE=$1

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: File $TEMPLATE_FILE not found"
    exit 1
fi

echo "Variables found in $TEMPLATE_FILE:"
grep -o '__[A-Z_]*__' "$TEMPLATE_FILE" | sort | uniq

echo ""
echo "op:// references found:"
grep -o 'op://[^"]*' "$TEMPLATE_FILE" | sort | uniq

echo ""
echo "Remember to replace these before deployment!"
