#Requires AutoHotkey v2.0
#SingleInstance Force

; Darklock - lock the PC and turn the monitor off with one keybind.
; Left-click the tray icon to set the keybind. No keybind is set by default.
; The keybind can be any combination of keyboard keys (F9 + F24 + Backspace + Win, ...).
; Mouse buttons are not supported.
; Settings are stored in %APPDATA%\Darklock (nothing is written next to the script).

DataDir := A_AppData "\Darklock"
DirCreate(DataDir)
IniFile := DataDir "\Darklock.ini"

; Keys of the active keybind (virtual-key codes) and of the one being recorded.
Chord := []
Pending := []
Registered := []
Fired := false
Recording := false
RecSeen := []

; Keep the tray icon available even when no hotkey is configured.
Persistent()

try TraySetIcon(FileExist(DataDir "\Darklock.ico") ? DataDir "\Darklock.ico" : A_ScriptDir "\Darklock.ico")
A_IconTip := "Darklock"

A := A_TrayMenu
A.Delete()
A.Add("Set keybind", (*) => ShowGui())
A.Add("Exit", (*) => ExitApp())
A.Default := "Set keybind"
A.ClickCount := 1

BuildGui()
SetChord(LoadChord())


BuildGui()
{
    global G, KeyTxt, RecBtn, StatusTxt
    G := Gui("+AlwaysOnTop -MaximizeBox", "Darklock")
    G.SetFont("s9")
    G.Add("Text", "w250", "Keybind to lock and sleep the screen:")
    KeyTxt := G.Add("Edit", "w250 ReadOnly Center")
    RecBtn := G.Add("Button", "w250", "Record keybind")
    RecBtn.OnEvent("Click", ToggleRecord)
    G.Add("Button", "w121", "Save").OnEvent("Click", SaveKey)
    G.Add("Button", "x+8 w121", "Clear").OnEvent("Click", ClearKey)
    StatusTxt := G.Add("Text", "xm w250 cGray")
    G.OnEvent("Close", HideGui)
    G.OnEvent("Escape", HideGui)
}


ShowGui()
{
    global G, KeyTxt, Chord, Pending, StatusTxt
    ; Turn the keybind off while the window is open so changing it can't trigger a lock.
    Arm(false)
    Pending := Chord.Clone()
    KeyTxt.Value := ChordName(Pending)
    StatusTxt.Text := Chord.Length = 0 ? "No keybind set." : "Current keybind is active."
    G.Show("AutoSize")
}


HideGui(*)
{
    global G
    StopRecord()
    G.Hide()
    Arm(true)
}


ToggleRecord(*)
{
    global Recording
    if Recording
        StopRecord()
    else
        StartRecord()
}


StartRecord()
{
    global Recording, RecSeen, RecBtn, StatusTxt, RecStart
    Recording := true
    RecSeen := []
    RecStart := A_TickCount
    RecBtn.Text := "Cancel"
    StatusTxt.Text := "Hold all the keys, then let go."
    SetTimer(RecordTick, 15)
}


StopRecord()
{
    global Recording, RecBtn
    if !Recording
        return
    Recording := false
    SetTimer(RecordTick, 0)
    RecBtn.Text := "Record keybind"
}


; Collects every key held at once. When everything is released the combination is done.
RecordTick()
{
    global RecSeen, RecStart, Pending, KeyTxt, StatusTxt
    down := KeysDown()
    for vk in down
        if !HasValue(RecSeen, vk)
            RecSeen.Push(vk)
    if down.Length = 0 && RecSeen.Length > 0
    {
        Pending := RecSeen.Clone()
        KeyTxt.Value := ChordName(Pending)
        StopRecord()
        StatusTxt.Text := "Press Save to use it."
    }
    else if down.Length = 0 && A_TickCount - RecStart > 15000
    {
        StopRecord()
        StatusTxt.Text := "Nothing was pressed."
    }
}


SaveKey(*)
{
    global Pending, StatusTxt
    if Pending.Length = 0
    {
        ClearKey()
        return
    }
    SetChord(Pending)
    StatusTxt.Text := "Saved: " ChordName(Pending)
    HideGui()
}


ClearKey(*)
{
    global Pending, KeyTxt, StatusTxt
    StopRecord()
    Pending := []
    KeyTxt.Value := ""
    SetChord([])
    StatusTxt.Text := "Keybind cleared."
}


; Stores the keybind (empty list = none). The keys are armed when the window is closed.
SetChord(keys)
{
    global Chord, IniFile
    Arm(false)
    Chord := keys.Clone()
    s := ""
    for vk in Chord
        s .= (s = "" ? "" : ",") Format("{:X}", vk)
    try IniWrite(s, IniFile, "Darklock", "Keys")
    Arm(true)
}


LoadChord()
{
    global IniFile
    s := IniRead(IniFile, "Darklock", "Keys", "")
    if s = ""
        return MigrateOldKey(IniRead(IniFile, "Darklock", "Hotkey", ""))
    keys := []
    for part in StrSplit(s, ",")
        if part != "" && IsXDigit(part)
            keys.Push(Integer("0x" part))
    return keys
}


; Older versions stored a single AutoHotkey hotkey such as ^!F24.
MigrateOldKey(old)
{
    keys := []
    while old != "" && InStr("^!+#", SubStr(old, 1, 1))
    {
        keys.Push(Map("^", 0x11, "!", 0x12, "+", 0x10, "#", 0x5B)[SubStr(old, 1, 1)])
        old := SubStr(old, 2)
    }
    if old != ""
    {
        vk := GetKeyVK(old)
        if vk
            keys.Push(vk)
        else
            return []
    }
    return keys
}


; Turns the keybind on or off.
Arm(on)
{
    global Chord, Registered, Fired
    for name in Registered
        try Hotkey(name, , "Off")
    Registered := []
    Fired := false
    if !on || Chord.Length = 0
        return
    for vk in Chord
        for real in Expand(vk)
        {
            down := "~*" Format("vk{:02X}", real)
            Registered.Push(down)
            Hotkey(down, ChordDown, "On")
            Registered.Push(down " up")
            Hotkey(down " up", ChordUp, "On")
        }
}


; A key of the keybind went down: fire once when all of them are held.
ChordDown(*)
{
    global Chord, Fired
    if Fired
        return
    for vk in Chord
        if !KeyIsDown(vk)
            return
    Fired := true
    LockNow()
}


ChordUp(*)
{
    global Fired
    Fired := false
}


; Modifiers match either side: Shift/Ctrl/Alt (0x10-0x12) and the Windows keys.
Expand(vk)
{
    switch vk
    {
        case 0x10: return [0xA0, 0xA1]
        case 0x11: return [0xA2, 0xA3]
        case 0x12: return [0xA4, 0xA5]
        case 0x5B: return [0x5B, 0x5C]
        default: return [vk]
    }
}


KeyIsDown(vk)
{
    for real in Expand(vk)
        if GetKeyState(Format("vk{:02X}", real))
            return true
    return false
}


; Normalized virtual-key codes of all keyboard keys currently held.
KeysDown()
{
    out := []
    Loop 247
    {
        vk := A_Index + 7  ; 0x08-0xFE; 0x01-0x07 are mouse buttons
        if vk >= 0x10 && vk <= 0x12 || vk = 0x5C
            continue
        if GetKeyState(Format("vk{:02X}", vk))
            out.Push(vk >= 0xA0 && vk <= 0xA5 ? 0x10 + (vk - 0xA0) // 2 : vk)
    }
    return out
}


HasValue(list, v)
{
    for x in list
        if x = v
            return true
    return false
}


ChordName(keys)
{
    mods := [], rest := []
    for vk in keys
        (vk = 0x10 || vk = 0x11 || vk = 0x12 || vk = 0x5B ? mods : rest).Push(vk)
    out := ""
    for vk in mods
        out .= (out = "" ? "" : " + ") (vk = 0x5B ? "Win" : GetKeyName(Format("vk{:02X}", vk)))
    for vk in rest
        out .= (out = "" ? "" : " + ") GetKeyName(Format("vk{:02X}", vk))
    return out
}


LockNow(*)
{
    ; Lock workstation
    DllCall("user32.dll\LockWorkStation")

    ; Give Windows time to enter locked state
    Sleep 1200

    ; Turn off monitor (broadcast)
    WM_SYSCOMMAND := 0x0112
    SC_MONITORPOWER := 0xF170
    HWND_BROADCAST := 0xFFFF

    PostMessage(WM_SYSCOMMAND, SC_MONITORPOWER, 2, , HWND_BROADCAST)
}
