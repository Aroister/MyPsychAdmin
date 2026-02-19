# ============================================
# MyPsy.dmg Settings — Professional DMG Layout
# ============================================

import os

# Path where the build happens
app_path = os.path.abspath("dist/MyPsy.app")

volume_name = "MyPsy"
format = "UDZO"              # compressed DMG (standard)
size = None                  # auto

files = [app_path]

symlinks = {
    "Applications": "/Applications"
}

# Background image
background = "dmg_resources/background.png"

# Icon positions inside DMG window
# Coordinates are in pixels from bottom-left corner
icon_locations = {
    "MyPsy.app": (140, 180),
    "Applications": (440, 180),
}

# Window size and position
window_rect = ((100, 100), (600, 400))  # ((x, y), (width, height))

# Icon size
icon_size = 128

# Hide everything unnecessary
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False

# Keep window background color behind PNG transparent
# (Some macOS versions require this)
default_view = "icon-view"
