#!/bin/bash
cd "$(dirname "$0")"
python3 license_generator.py
echo ""
echo "Press any key to close..."
read -n 1
