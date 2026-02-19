#!/bin/bash

echo "=============================="
echo " MyPsy2.6 macOS Setup (Python 3.13)"
echo "=============================="

# ------------------------------
# 1) Locate MyPsy directory
# ------------------------------
TARGET_DIR="/Users/avie/Desktop/MPA2/Versions/MyPsy2.6"

if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ ERROR: Could not find MyPsy directory at:"
    echo "   $TARGET_DIR"
    exit 1
fi

cd "$TARGET_DIR"
echo "📁 Working directory: $TARGET_DIR"

# ------------------------------
# 2) Deactivate old venv if active
# ------------------------------
if [[ "$VIRTUAL_ENV" != "" ]]; then
    echo "🔌 Deactivating old virtual environment…"
    deactivate
fi

# ------------------------------
# 3) Remove old venv
# ------------------------------
if [ -d "venv" ]; then
    echo "🗑  Removing old venv…"
    rm -rf venv
else
    echo "ℹ️ No old venv found, skipping removal."
fi

# ------------------------------
# 4) Check Python 3.13 availability
# ------------------------------
if ! command -v python3.13 &> /dev/null; then
    echo "❌ Python 3.13 not found."
    echo "Install it using:"
    echo "    brew install python@3.13"
    exit 1
fi

echo "🐍 Python 3.13 found: $(python3.13 --version)"

# ------------------------------
# 5) Create new venv
# ------------------------------
echo "✨ Creating new Python 3.13 virtual environment…"
python3.13 -m venv venv

# ------------------------------
# 6) Activate venv
# ------------------------------
echo "🔧 Activating new venv…"
source venv/bin/activate

# ------------------------------
# 7) Upgrade pip
# ------------------------------
echo "⬆️ Upgrading pip…"
pip install --upgrade pip

# ------------------------------
# 8) Install core dependencies
# ------------------------------
echo "📦 Installing dependencies…"

pip install PySide6==6.6.1
pip install pandas numpy python-docx ecdsa
pip install pymupdf
pip install pytesseract

# ------------------------------
# 9) Validate cocoa plugin
# ------------------------------
echo "🔍 Checking Qt cocoa plugin…"

python3 - << 'EOF'
import PySide6, os
platform_path = os.path.join(os.path.dirname(PySide6.__file__), "Qt", "plugins", "platforms")
print("Platform plugin directory:", platform_path)
if os.path.isdir(platform_path):
    print("Contents:", os.listdir(platform_path))
else:
    print("❌ ERROR: Platform plugin directory missing!")
EOF

# ------------------------------
# 10) Launch MyPsy
# ------------------------------
echo ""
echo "🚀 Launching MyPsy…"
python3 main.py

echo ""
echo "🎉 Setup complete!"
