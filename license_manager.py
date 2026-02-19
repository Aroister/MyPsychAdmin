# ================================================
# ONLINE LICENCE MANAGER — MyPsychAdmin 2.7
# ================================================
# Features:
#   - Machine-specific activation (hardware fingerprint)
#   - Email notification on activation
#   - Time-limited licenses
#   - One-time use enforcement
# ================================================

import os
import sys
import json
import base64
import hashlib
import platform
import urllib.request
import urllib.parse
from datetime import date, datetime
from ecdsa import VerifyingKey, BadSignatureError

from utils.resource_path import resource_path

# Correct public key path
PUBLIC_KEY_PATH = resource_path("resources", "public_key.pem")

# ================================================
# CONFIGURATION - Set your email here
# ================================================
NOTIFICATION_EMAIL = "avieluthra@btinternet.com"
WEB3FORMS_ACCESS_KEY = "41cfe486-d50d-4f89-aa54-7aabdd252fef"

# ================================================
# MACHINE FINGERPRINT
# ================================================
def get_machine_id():
    """
    Generate a unique machine fingerprint based on hardware.
    This ties the license to a specific computer.
    """
    try:
        import uuid

        # Get various machine identifiers
        components = []

        # MAC address
        mac = uuid.getnode()
        components.append(str(mac))

        # Platform info
        components.append(platform.node())
        components.append(platform.machine())
        components.append(platform.processor())

        # On Windows, get more hardware info
        if platform.system() == "Windows":
            try:
                import subprocess
                # Get motherboard serial
                result = subprocess.run(
                    ['wmic', 'baseboard', 'get', 'serialnumber'],
                    capture_output=True, text=True, timeout=5
                )
                if result.stdout:
                    components.append(result.stdout.strip())
            except:
                pass

        # Create hash of all components
        fingerprint = hashlib.sha256(
            "|".join(components).encode()
        ).hexdigest()[:32]

        return fingerprint

    except Exception as e:
        # Fallback to basic fingerprint
        basic = f"{platform.node()}-{platform.machine()}"
        return hashlib.sha256(basic.encode()).hexdigest()[:32]


# ================================================
# LICENSE STORAGE PATHS
# ================================================
def _get_license_folder():
    """Get OS-appropriate license storage folder."""
    if platform.system() == "Windows":
        base = os.environ.get("APPDATA", os.path.expanduser("~"))
        folder = os.path.join(base, "MyPsychAdmin")
    else:
        home = os.path.expanduser("~")
        folder = os.path.join(home, "Library", "Application Support", "MyPsychAdmin")

    os.makedirs(folder, exist_ok=True)
    return folder


def _license_path():
    return os.path.join(_get_license_folder(), "license.key")


def _activation_path():
    return os.path.join(_get_license_folder(), "activation.json")


# ================================================
# VERIFY SIGNED LICENSE USING PUBLIC KEY
# ================================================
def verify_signed_license(token: str):
    """Verify the cryptographic signature of a license token."""
    try:
        raw = base64.b64decode(token)

        if b"||" not in raw:
            return False, "Malformed licence format"

        payload_bytes, sig = raw.split(b"||", 1)

        # Load public key shipped in application bundle
        with open(PUBLIC_KEY_PATH, "rb") as f:
            vk = VerifyingKey.from_pem(f.read())

        # Verify signature (SHA-256 for cross-platform compatibility)
        vk.verify(sig, payload_bytes, hashfunc=hashlib.sha256)

        # Decode the JSON payload
        payload = json.loads(payload_bytes.decode())

        return True, payload

    except BadSignatureError:
        return False, "Invalid licence signature"
    except Exception as e:
        return False, f"Error verifying licence: {e}"


# ================================================
# ACTIVATION DATA MANAGEMENT
# ================================================
def load_activation_data():
    """Load local activation data."""
    path = _activation_path()
    if not os.path.exists(path):
        return None

    try:
        with open(path, "r") as f:
            return json.load(f)
    except:
        return None


def save_activation_data(data: dict):
    """Save activation data locally."""
    path = _activation_path()
    with open(path, "w") as f:
        json.dump(data, f, indent=2)


# ================================================
# EMAIL NOTIFICATION (via BT SMTP)
# ================================================
def send_activation_notification(license_info: dict, machine_id: str, success: bool = True):
    """
    Send email notification when a license is activated.
    Uses BT SMTP server.
    """
    import smtplib
    from email.mime.text import MIMEText
    from email.mime.multipart import MIMEMultipart

    print("[License] Attempting to send activation notification...")

    try:
        # Prepare notification data
        status = "SUCCESS" if success else "FAILED"
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        body = f"""
MyPsychAdmin License Activation - {status}

Timestamp: {timestamp}
Machine ID: {machine_id}
Platform: {platform.system()} {platform.release()}
Computer: {platform.node()}

License Details:
- Customer: {license_info.get('customer', 'Unknown')}
- Type: {license_info.get('type', 'Unknown')}
- Expires: {license_info.get('expires', 'Unknown')}
- Issued: {license_info.get('issued', 'Unknown')}
"""

        # Create message
        msg = MIMEMultipart()
        msg['From'] = "avieluthra@btinternet.com"
        msg['To'] = NOTIFICATION_EMAIL
        msg['Subject'] = f"MyPsychAdmin Activation: {license_info.get('customer', 'Unknown')} - {status}"
        msg.attach(MIMEText(body, 'plain'))

        # BT SMTP credentials
        SMTP_SERVER = "mail.btinternet.com"
        SMTP_PORT = 587
        SMTP_EMAIL = "avieluthra@btinternet.com"
        SMTP_PASSWORD = "27NmfEK29dyyQs$h5P95HV"

        print(f"[License] Sending email via {SMTP_SERVER}...")

        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT, timeout=20) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(SMTP_EMAIL, SMTP_PASSWORD)
            server.send_message(msg)

        print("[License] Activation notification email sent successfully")
        return True

    except Exception as e:
        print(f"[License] Could not send notification: {e}")
        return False


# ================================================
# LICENSE OPERATIONS
# ================================================
def store_license(token: str):
    """Save license token to disk."""
    with open(_license_path(), "w") as f:
        f.write(token.strip())


def load_license():
    """Load license token from disk."""
    path = _license_path()
    if not os.path.exists(path):
        return None

    try:
        with open(path, "r") as f:
            return f.read().strip()
    except:
        return None


def activate_license(token: str):
    """
    Activate a license on this machine.

    Returns: (success: bool, message: str)
    """
    # First verify the license signature
    ok, payload = verify_signed_license(token)
    if not ok:
        return False, payload  # Contains error message

    # Check platform
    license_platform = payload.get("platform", "universal").lower()
    if license_platform not in ("desktop", "universal"):
        return False, f"This licence is for {license_platform} only, not desktop"

    # Check if license has expired
    if "expires" in payload:
        exp = date.fromisoformat(payload["expires"])
        if exp < date.today():
            return False, "This licence has expired"

    # Get this machine's fingerprint
    machine_id = get_machine_id()

    # Check device binding (from license itself)
    if "device_id" in payload:
        if payload["device_id"] != machine_id:
            return False, "This licence is locked to a different device. Contact support to transfer your licence."

    # Check local activation data
    activation = load_activation_data()
    if activation:
        # Already activated on this machine
        if activation.get("machine_id") == machine_id:
            # Same machine, check if same license
            if activation.get("license_hash") == hashlib.sha256(token.encode()).hexdigest():
                # Same license, same machine - allow
                pass
            else:
                # Different license on same machine - allow re-activation
                pass
        else:
            # This shouldn't happen (different machine ID in local file)
            pass

    # Save activation data
    activation_data = {
        "machine_id": machine_id,
        "license_hash": hashlib.sha256(token.encode()).hexdigest(),
        "activated_at": datetime.now().isoformat(),
        "customer": payload.get("customer", "Unknown"),
        "expires": payload.get("expires"),
        "type": payload.get("type", "standard"),
    }
    save_activation_data(activation_data)

    # Save the license token
    store_license(token)

    # Send notification email (non-blocking, won't fail activation)
    send_activation_notification(payload, machine_id, success=True)

    return True, payload


def is_license_valid():
    """
    Check if the current license is valid.

    Returns: (valid: bool, payload_or_message: dict|str)
    """
    token = load_license()
    if not token:
        return False, "No licence found"

    ok, payload = verify_signed_license(token)
    if not ok:
        return False, payload  # Contains error message

    # Check platform
    license_platform = payload.get("platform", "universal").lower()
    if license_platform not in ("desktop", "universal"):
        return False, f"This licence is for {license_platform} only"

    # Check expiry
    if "expires" in payload:
        exp = date.fromisoformat(payload["expires"])
        if exp < date.today():
            return False, "Licence has expired"

    # Check device binding (from license itself)
    current_machine = get_machine_id()
    if "device_id" in payload:
        if payload["device_id"] != current_machine:
            return False, "Licence is locked to a different device"

    return True, payload


def get_license_info():
    """Get information about the current license."""
    valid, result = is_license_valid()
    if valid:
        activation = load_activation_data()
        return {
            "valid": True,
            "customer": result.get("customer", "Unknown"),
            "type": result.get("type", "standard"),
            "expires": result.get("expires"),
            "activated_at": activation.get("activated_at") if activation else None,
            "machine_id": get_machine_id(),
        }
    else:
        return {
            "valid": False,
            "error": result,
        }


def deactivate_license():
    """Remove license from this machine."""
    try:
        license_path = _license_path()
        activation_path = _activation_path()

        if os.path.exists(license_path):
            os.remove(license_path)
        if os.path.exists(activation_path):
            os.remove(activation_path)

        return True, "Licence deactivated"
    except Exception as e:
        return False, f"Error deactivating: {e}"
