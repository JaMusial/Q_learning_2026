#!/usr/bin/env python3
"""Quick script to check JSON structure."""

import json
from pathlib import Path

log_file = Path(__file__).parent.parent / 'logi_before_learning.json'
print(f"Loading {log_file}...")

with open(log_file, 'r') as f:
    data = json.load(f)

print(f"\nTop-level keys: {list(data.keys())}")

# Check if it's a nested structure
if isinstance(data, dict):
    for key in list(data.keys())[:5]:  # First 5 keys
        value = data[key]
        if isinstance(value, list):
            print(f"\n{key}: list with {len(value)} elements")
            if len(value) > 0:
                print(f"  First element type: {type(value[0])}")
                print(f"  First element: {value[0]}")
        elif isinstance(value, dict):
            print(f"\n{key}: dict with keys: {list(value.keys())}")
        else:
            print(f"\n{key}: {type(value)}")
