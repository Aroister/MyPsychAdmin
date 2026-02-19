#!/usr/bin/env python3
"""
MyPsychAdmin License Generator v2.0
============================
Generates time-limited, single-use license keys.

Features:
- Time-limited licenses (30 days, 1 year, etc.)
- Email notification when activated (requires Web3Forms setup)
- Machine-bound (once activated, tied to that computer)

Usage:
    python license_generator.py

KEEP THIS FILE AND THE PRIVATE KEY SECRET!
"""

import os
import json
import base64
import hashlib
from datetime import date, timedelta
from ecdsa import SigningKey, NIST256p

KEYS_DIR = os.path.dirname(os.path.abspath(__file__))
PRIVATE_KEY_PATH = os.path.join(KEYS_DIR, "private_key.pem")
PUBLIC_KEY_PATH = os.path.join(KEYS_DIR, "resources", "public_key.pem")


def generate_key_pair():
    """Generate a new ECDSA key pair."""
    print("Generating new ECDSA key pair...")

    sk = SigningKey.generate(curve=NIST256p)
    vk = sk.get_verifying_key()

    with open(PRIVATE_KEY_PATH, "wb") as f:
        f.write(sk.to_pem())
    print(f"Private key saved to: {PRIVATE_KEY_PATH}")
    print("!!! KEEP THIS FILE SECRET - DO NOT DISTRIBUTE !!!")

    os.makedirs(os.path.dirname(PUBLIC_KEY_PATH), exist_ok=True)
    with open(PUBLIC_KEY_PATH, "wb") as f:
        f.write(vk.to_pem())
    print(f"Public key saved to: {PUBLIC_KEY_PATH}")

    return sk


def load_private_key():
    """Load the private key from file."""
    if not os.path.exists(PRIVATE_KEY_PATH):
        return generate_key_pair()

    with open(PRIVATE_KEY_PATH, "rb") as f:
        return SigningKey.from_pem(f.read())


def generate_license(customer_name: str, expiry_date: str, license_type: str = "standard",
                     platform: str = "universal", device_id: str = None):
    """
    Generate a signed license key.

    Args:
        customer_name: Name of the customer/organization
        expiry_date: Expiry date in YYYY-MM-DD format
        license_type: "trial", "standard", "professional", or "lifetime"
        platform: "desktop", "ios", or "universal"
        device_id: Optional device ID to lock license to specific device

    Returns:
        Base64-encoded license key string
    """
    sk = load_private_key()

    payload = {
        "customer": customer_name,
        "expires": expiry_date,
        "type": license_type,
        "platform": platform,
        "issued": date.today().isoformat(),
    }

    # Add device binding if specified
    if device_id:
        payload["device_id"] = device_id

    payload_bytes = json.dumps(payload, separators=(',', ':')).encode()
    # Use SHA-256 for compatibility with iOS CryptoKit
    signature = sk.sign(payload_bytes, hashfunc=hashlib.sha256)
    token = payload_bytes + b"||" + signature
    license_key = base64.b64encode(token).decode()

    return license_key, payload


def main():
    print("=" * 60)
    print("MyPsychAdmin License Generator v2.0")
    print("=" * 60)
    print()
    print("This generates TIME-LIMITED, SINGLE-USE license keys.")
    print("Once a key is activated on a machine, it cannot be used elsewhere.")
    print()

    if not os.path.exists(PRIVATE_KEY_PATH):
        print("No private key found. Generating new key pair...")
        generate_key_pair()
        print()
        print("IMPORTANT: After generating new keys, you must rebuild the app")
        print("to include the new public key!")
        print()

    # Get customer info
    print("-" * 60)
    customer = input("Customer name: ").strip()
    if not customer:
        customer = "Licensed User"

    # Get expiry duration
    print("\nLicense Duration:")
    print("  1. 30-day trial")
    print("  2. 90-day license")
    print("  3. 1 year license")
    print("  4. 2 year license")
    print("  5. Custom date (YYYY-MM-DD)")
    print("  6. Lifetime (expires 2099)")

    choice = input("\nSelect option [1-6]: ").strip()

    duration_map = {
        "1": (30, "trial"),
        "2": (90, "standard"),
        "3": (365, "standard"),
        "4": (730, "professional"),
    }

    if choice in duration_map:
        days, default_type = duration_map[choice]
        expiry = (date.today() + timedelta(days=days)).isoformat()
    elif choice == "5":
        expiry = input("Enter date (YYYY-MM-DD): ").strip()
        default_type = "standard"
    elif choice == "6":
        expiry = "2099-12-31"
        default_type = "lifetime"
    else:
        expiry = (date.today() + timedelta(days=365)).isoformat()
        default_type = "standard"

    # Get license type
    print("\nLicense Type:")
    print("  1. Trial (limited features)")
    print("  2. Standard")
    print("  3. Professional")
    print("  4. Lifetime")

    type_choice = input(f"\nSelect type [1-4] (default: {default_type}): ").strip()
    license_type = {
        "1": "trial",
        "2": "standard",
        "3": "professional",
        "4": "lifetime"
    }.get(type_choice, default_type)

    # Get platform
    print("\nPlatform:")
    print("  1. Desktop only")
    print("  2. iOS only")
    print("  3. Universal (both platforms)")

    platform_choice = input("\nSelect platform [1-3] (default: 3): ").strip()
    platform = {
        "1": "desktop",
        "2": "ios",
        "3": "universal"
    }.get(platform_choice, "universal")

    # Get device ID for device-bound license
    print("\nDevice Binding:")
    print("  Leave blank for any device on the selected platform")
    print("  Or enter the Device ID shown in the app's activation screen")
    device_id = input("\nDevice ID (optional): ").strip() or None

    # Calculate days until expiry
    exp_date = date.fromisoformat(expiry)
    days_remaining = (exp_date - date.today()).days

    # Generate license
    print("\nGenerating license...")
    license_key, payload = generate_license(customer, expiry, license_type, platform, device_id)

    print("\n" + "=" * 60)
    print("LICENSE GENERATED SUCCESSFULLY")
    print("=" * 60)
    print(f"\nCustomer: {payload['customer']}")
    print(f"Type: {payload['type'].upper()}")
    print(f"Platform: {payload['platform'].upper()}")
    if payload.get('device_id'):
        print(f"Device ID: {payload['device_id']} (LOCKED)")
    else:
        print("Device ID: Any device")
    print(f"Expires: {payload['expires']} ({days_remaining} days)")
    print(f"Issued: {payload['issued']}")
    print("\n" + "-" * 60)
    print("LICENSE KEY:")
    print("-" * 60)
    print(license_key)
    print("-" * 60)

    print("\nNOTES:")
    if payload.get('device_id'):
        print(f"- This key ONLY works on device: {payload['device_id']}")
        print("- To transfer to a new device, generate a new license with the new Device ID")
    else:
        print(f"- This key works on any {payload['platform']} device")
    print("- You will receive an email when it is activated")
    print("- The license expires on", expiry)

    # Ask to generate another
    print()
    another = input("Generate another license? [y/N]: ").strip().lower()
    if another == 'y':
        print("\n")
        main()


if __name__ == "__main__":
    main()
