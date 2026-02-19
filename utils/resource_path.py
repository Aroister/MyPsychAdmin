# utils/resource_path.py
import sys
import os


# -----------------------------------------------------------
# RESOURCE ROOT (project root or PyInstaller bundle root)
# -----------------------------------------------------------
def resource_root():
    """
    Returns the base directory for static assets:
      • In PyInstaller: sys._MEIPASS
      • In dev mode: project root (one level above utils/)
    """
    # PyInstaller bundle root
    if hasattr(sys, "_MEIPASS"):
        return sys._MEIPASS

    # Development: directory above utils/
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# -----------------------------------------------------------
# RESOLVE PATH TO A RESOURCE
# -----------------------------------------------------------
def resource_path(*paths):
    """
    Return an absolute path to a file inside the project/bundle.
    Usage:
        resource_path("resources", "icons", "MyPsy.icns")
        resource_path("resources", "public_key.pem")
    """
    return os.path.join(resource_root(), *paths)


# -----------------------------------------------------------
# USER DATA DIRECTORY (writable)
# -----------------------------------------------------------
def user_data_dir():
    """
    Platform-correct writable directory:
      • macOS: ~/Library/Application Support/MyPsy
      • Windows: %APPDATA%/MyPsy
      • Linux: ~/.local/share/MyPsy
    """
    if sys.platform == "darwin":
        base = os.path.expanduser("~/Library/Application Support/MyPsy")
    elif sys.platform.startswith("win"):
        base = os.path.join(os.getenv("APPDATA"), "MyPsy")
    else:
        base = os.path.expanduser("~/.local/share/MyPsy")

    os.makedirs(base, exist_ok=True)
    return base


def user_data_path(filename):
    """Path inside the user-writable directory."""
    return os.path.join(user_data_dir(), filename)
