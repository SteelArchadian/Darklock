# Darklock

A tiny AutoHotkey v2 tray tool: press one keybind and your PC locks and the monitors turn off.

## Features
- Sits in the system tray and waits for your keybind.
- Left-click the tray icon to open a small window where you record the keybind.
- The keybind can be any combination of keyboard keys (for example F9 + F24 + Backspace + Win). Mouse buttons are not supported.
- No keybind is set by default.
- Fires once per press; the keys still do their normal job in other programs.
- Shift, Ctrl, Alt and Win match the left or right key.
- Settings are saved in `%APPDATA%\Darklock\Darklock.ini`; nothing is written next to the script.

## Install
1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Download `Darklock.ahk` and double-click it.
3. Left-click the tray icon, press **Record keybind**, hold your keys, let go, then **Save**.

Optional: put a `Darklock.ico` next to the script (or in `%APPDATA%\Darklock`) to use it as the tray icon.

## How it works
The keybind fires `LockWorkStation`, waits 1.2 seconds, then broadcasts a monitor-off system command.

## License
MIT
