"""
MyPsychAdmin Web Installer
Downloads and installs MyPsychAdmin from GitHub
"""
import os
import sys
import urllib.request
import tkinter as tk
from tkinter import ttk, messagebox
import threading
import winreg
import subprocess

# Configuration
APP_NAME = "MyPsychAdmin"
DOWNLOAD_URL = "https://github.com/Aroister/MyPsychAdmin/releases/download/v2.7/MyPsychAdmin.exe"
VERSION = "2.7"

class InstallerApp:
    def __init__(self, root):
        self.root = root
        self.root.title(f"Install {APP_NAME}")
        self.root.geometry("450x280")
        self.root.resizable(False, False)

        # Center window
        self.root.update_idletasks()
        x = (self.root.winfo_screenwidth() // 2) - 225
        y = (self.root.winfo_screenheight() // 2) - 140
        self.root.geometry(f"+{x}+{y}")

        # Main frame
        frame = ttk.Frame(root, padding=20)
        frame.pack(fill=tk.BOTH, expand=True)

        # Title
        title = ttk.Label(frame, text=f"{APP_NAME} Installer", font=("Segoe UI", 16, "bold"))
        title.pack(pady=(0, 10))

        # Description
        desc = ttk.Label(frame, text=f"This will download and install {APP_NAME} v{VERSION}\non your computer.", justify=tk.CENTER)
        desc.pack(pady=(0, 20))

        # Install location
        self.install_path = os.path.join(os.environ.get("LOCALAPPDATA", ""), APP_NAME)
        path_label = ttk.Label(frame, text=f"Install location: {self.install_path}", font=("Segoe UI", 9))
        path_label.pack(pady=(0, 15))

        # Progress bar (hidden initially)
        self.progress = ttk.Progressbar(frame, length=400, mode='determinate')
        self.progress.pack(pady=(0, 10))
        self.progress.pack_forget()

        # Status label
        self.status_var = tk.StringVar(value="Click Install to begin")
        self.status_label = ttk.Label(frame, textvariable=self.status_var)
        self.status_label.pack(pady=(0, 15))

        # Buttons frame
        btn_frame = ttk.Frame(frame)
        btn_frame.pack(fill=tk.X)

        self.install_btn = ttk.Button(btn_frame, text="Install", command=self.start_install, width=15)
        self.install_btn.pack(side=tk.LEFT, padx=5)

        self.cancel_btn = ttk.Button(btn_frame, text="Cancel", command=root.quit, width=15)
        self.cancel_btn.pack(side=tk.RIGHT, padx=5)

        # Desktop shortcut checkbox
        self.desktop_shortcut = tk.BooleanVar(value=True)
        self.shortcut_check = ttk.Checkbutton(frame, text="Create desktop shortcut", variable=self.desktop_shortcut)
        self.shortcut_check.pack(pady=(10, 0))

    def start_install(self):
        self.install_btn.config(state=tk.DISABLED)
        self.shortcut_check.config(state=tk.DISABLED)
        self.progress.pack(pady=(0, 10))
        self.status_var.set("Downloading...")

        # Run download in separate thread
        thread = threading.Thread(target=self.download_and_install)
        thread.daemon = True
        thread.start()

    def download_and_install(self):
        try:
            # Create install directory
            os.makedirs(self.install_path, exist_ok=True)
            exe_path = os.path.join(self.install_path, f"{APP_NAME}.exe")

            # Download with progress
            def progress_hook(block_num, block_size, total_size):
                if total_size > 0:
                    percent = min(100, block_num * block_size * 100 / total_size)
                    self.root.after(0, lambda: self.progress.config(value=percent))
                    self.root.after(0, lambda: self.status_var.set(f"Downloading... {percent:.0f}%"))

            urllib.request.urlretrieve(DOWNLOAD_URL, exe_path, progress_hook)

            # Create shortcuts
            self.root.after(0, lambda: self.status_var.set("Creating shortcuts..."))

            if self.desktop_shortcut.get():
                self.create_shortcut(exe_path, "Desktop")

            # Create Start Menu shortcut
            self.create_shortcut(exe_path, "StartMenu")

            # Success
            self.root.after(0, self.install_complete)

        except Exception as e:
            self.root.after(0, lambda: self.install_failed(str(e)))

    def create_shortcut(self, target, location):
        try:
            import ctypes.wintypes

            if location == "Desktop":
                # Get desktop path
                CSIDL_DESKTOP = 0
                buf = ctypes.create_unicode_buffer(ctypes.wintypes.MAX_PATH)
                ctypes.windll.shell32.SHGetFolderPathW(None, CSIDL_DESKTOP, None, 0, buf)
                shortcut_dir = buf.value
            else:
                # Start Menu
                shortcut_dir = os.path.join(os.environ.get("APPDATA", ""), "Microsoft", "Windows", "Start Menu", "Programs")

            shortcut_path = os.path.join(shortcut_dir, f"{APP_NAME}.lnk")

            # Use PowerShell to create shortcut
            ps_script = f'''
            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut("{shortcut_path}")
            $Shortcut.TargetPath = "{target}"
            $Shortcut.WorkingDirectory = "{self.install_path}"
            $Shortcut.Description = "{APP_NAME}"
            $Shortcut.Save()
            '''
            subprocess.run(["powershell", "-Command", ps_script], capture_output=True)

        except Exception as e:
            print(f"Shortcut error: {e}")

    def install_complete(self):
        self.progress.config(value=100)
        self.status_var.set("Installation complete!")
        self.cancel_btn.config(text="Close")

        # Ask to launch
        if messagebox.askyesno("Installation Complete",
                               f"{APP_NAME} has been installed successfully!\n\nWould you like to launch it now?"):
            exe_path = os.path.join(self.install_path, f"{APP_NAME}.exe")
            subprocess.Popen([exe_path], cwd=self.install_path)

        self.root.quit()

    def install_failed(self, error):
        self.status_var.set("Installation failed!")
        messagebox.showerror("Installation Failed", f"An error occurred:\n\n{error}")
        self.install_btn.config(state=tk.NORMAL)
        self.shortcut_check.config(state=tk.NORMAL)


if __name__ == "__main__":
    root = tk.Tk()
    app = InstallerApp(root)
    root.mainloop()
