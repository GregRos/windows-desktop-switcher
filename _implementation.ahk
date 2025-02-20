﻿SetTitleMatchMode, RegEx
; Globals
DesktopCount := 2 ; Windows starts with 2 desktops at boot
CurrentDesktop := 1 ; Desktop count is 1-indexed (Microsoft numbers them this way)
LastOpenedDesktop := 1
global _g_desktopIdToName := {}

#include <TT>
; Required definition for TT.ahk
Struct(Structure,pointer:=0,init:=0){
    return new _Struct(Structure,pointer,init)
} 
; DLL
hVirtualDesktopAccessor := DllCall("LoadLibrary", "Str", A_ScriptDir . "\VirtualDesktopAccessor.dll", "Ptr")
global IsWindowOnDesktopNumberProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "IsWindowOnDesktopNumber", "Ptr")
global MoveWindowToDesktopNumberProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "MoveWindowToDesktopNumber", "Ptr")

; Main
SetKeyDelay, 75
mapDesktopsFromRegistry()
OutputDebug, [loading] desktops: %DesktopCount% current: %CurrentDesktop%

; This function examines the registry to build an accurate list of the current virtual desktops and which one we're currently on.
; List of desktops appears to be in HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops
; On Windows 11 the current desktop UUID appears to be in the same location
; On previous versions in HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SessionInfo\1\VirtualDesktops
;
mapDesktopsFromRegistry()
{
    global CurrentDesktop, DesktopCount
    desktopIdToName := {}
    ; Get the current desktop UUID. Length should be 32 always, but there's no guarantee this couldn't change in a later Windows release so we check.
    IdLength := 32
    SessionId := getSessionId()
    if (SessionId) {
        RegRead, CurrentDesktopId, HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops, CurrentVirtualDesktop
        if ErrorLevel {
            RegRead, CurrentDesktopId, HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SessionInfo\%SessionId%\VirtualDesktops, CurrentVirtualDesktop
        }

        if (CurrentDesktopId) {
            IdLength := StrLen(CurrentDesktopId)
        }
    }

    ; Get a list of the UUIDs for all virtual desktops on the system
    vdKey := "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops"
    RegRead, DesktopList, % vdKey, VirtualDesktopIDs
    if (DesktopList) {
        DesktopListLength := StrLen(DesktopList)
        ; Figure out how many virtual desktops there are
        DesktopCount := floor(DesktopListLength / IdLength)
    }
    else {
        DesktopCount := 1
    }

    ; Parse the REG_DATA string that stores the array of UUID's for virtual desktops in the registry.
    i := 0
    while (CurrentDesktopId and i < DesktopCount) {
        StartPos := (i * IdLength) + 1
        DesktopIter := SubStr(DesktopList, StartPos, IdLength)
        OutputDebug, The iterator is pointing at %DesktopIter% and count is %i%.
        desktopIdToName[i + 1] := DesktopIter
        ; Break out if we find a match in the list. If we didn't find anything, keep the
        ; old guess and pray we're still correct :-D.
        if (DesktopIter = CurrentDesktopId) {
            CurrentDesktop := i + 1
            OutputDebug, Current desktop number is %CurrentDesktop% with an ID of %DesktopIter%.
        }
        i++
    }

    for i, BinId in desktopIdToName {
        LastBinIdPart := SubStr(BinId, -7)
        hit := False
        Loop, Reg, % vdKey "\Desktops", RV
        {
            if (A_LoopRegName != "Name") {
                Continue
            }
            LastSubkeyPart := StrSplit(A_LoopRegSubkey, "\")
            LastSubkeyPart := Trim(LastSubkeyPart[LastSubkeyPart.MaxIndex()], "{}")
            LastRegIdPart := SubStr(LastSubkeyPart, -7)

            if (LastBinIdPart = LastRegIdPart) {
                RegRead, Name,% A_LoopRegKey "\" A_LoopRegSubkey, Name
                if (!ErrorLevel) {
                    desktopIdToName[i] := name
                    hit := true
                    break
                }
            }
        }
        if (!hit) {
            desktopIdToName[i] := "Desktop " i
        } 
        name := desktopIdToName[i]
        OutputDebug, %i% Desktop ID %BinId% called %name%
    }
    _g_desktopIdToName := desktopIdToName
}

;
; This functions finds out ID of current session.
;
getSessionId() {
    ProcessId := DllCall("GetCurrentProcessId", "UInt")
    if ErrorLevel {
        OutputDebug, Error getting current process id: %ErrorLevel%
        return
    }
    OutputDebug, Current Process Id: %ProcessId%

    DllCall("ProcessIdToSessionId", "UInt", ProcessId, "UInt*", SessionId)
    if ErrorLevel {
        OutputDebug, Error getting session id: %ErrorLevel%
        return
    }
    OutputDebug, Current Session Id: %SessionId%
    return SessionId
}

_switchDesktopToTarget(targetDesktop) {
    ; Globals variables should have been updated via updateGlobalVariables() prior to entering this function
    global CurrentDesktop, DesktopCount, LastOpenedDesktop
    prevDesktop := CurrentDesktop
    ; Don't attempt to switch to an invalid desktop
    if (targetDesktop > DesktopCount || targetDesktop < 1 || targetDesktop == CurrentDesktop) {
        OutputDebug, [invalid] target: %targetDesktop% current: %CurrentDesktop%
        return
    }

    LastOpenedDesktop := CurrentDesktop

    ; Fixes the issue of active windows in intermediate desktops capturing the switch shortcut and therefore delaying or stopping the switching sequence. This also fixes the flashing window button after switching in the taskbar. More info: https://github.com/pmb6tz/windows-desktop-switcher/pull/19
    WinActivate, ahk_class Shell_TrayWnd

    ; Go right until we reach the desktop we want
    while(CurrentDesktop < targetDesktop) {
        Send {LWin down}{LCtrl down}{Right down}{LWin up}{LCtrl up}{Right up}
        CurrentDesktop++
        OutputDebug, [right] target: %targetDesktop% current: %CurrentDesktop%
    }

    ; Go left until we reach the desktop we want
    while(CurrentDesktop > targetDesktop) {
        Send {LWin down}{LCtrl down}{Left down}{Lwin up}{LCtrl up}{Left up}
        CurrentDesktop--
        OutputDebug, [left] target: %targetDesktop% current: %CurrentDesktop%
    }
    ; Makes the WinActivate fix less intrusive
    Sleep, 50
    focusTheForemostWindow(targetDesktop)
    _notifyDesktopSwitched(prevDesktop, CurrentDesktop)

}

_getJetBrainsProjectName(hwnd) {
    WinGetTitle, windowTitle, % "ahk_id " hwnd
    ; Main Window
    results := StrSplit(windowTitle, " – ")
    if (results.MaxIndex() > 1) {
        project := results[1]
    }

    ; Tool Windows
    results := StrSplit(windowTitle, " - ")
    if (results.MaxIndex() > 1) {
        project := results[2]
    }
    if (!project) {
        return "ahk_id " hwnd
    }
regex = i).*( - \Q%project%\E|\Q%project%\E – ).*
return regex
}

_getSmartGitProjectName(hwnd) {
    WinGetTitle, windowTitle, % "ahk_id " hwnd
    return "\Q" windowTitle "\E"
}

_searchSiblingWindows(hwnd, searchTitle) {
    WinGet, pid, PID, % "ahk_id " hwnd
    search := searchTitle " ahk_pid " pid
    WinGet, hwndArray, List, % search
    Windows := []
    Loop, %hwndArray% {
        Current := hwndArray%A_Index%
        WinGetTitle, Title, % "ahk_id " Current
        OutputDebug, % "Related Window: " Title`
        Windows.Push(Current)
    }
    OutputDebug, % "Found " Windows.MaxIndex() " Windows"
    return Windows
}

_isJetBrains(hwnd) {
    WinGet, activePath, ProcessPath, % "ahk_id " hwnd
    return InStr(activePath, "JetBrains")
}

_isChromium(hwnd) {
    WinGet, activePath, ProcessPath, % "ahk_id " hwnd
    return InStr(activePath, ".local-chromium")
}

_isSmartGit(hwnd) {
    WinGet, activePath, ProcessPath, % "ahk_id" hwnd
    return InStr(activePath, "smartgit.exe")
}

_getRelatedWindows(hwnd) {
    if (_isJetBrains(hwnd)) {
        return _searchSiblingWindows(hwnd, _getJetBrainsProjectName(hwnd))
    }
    else if (_isChromium(hwnd)) {
        return _searchSiblingWindows(hwnd, "ahk_exe i)^.*.local-chromium.*$")
    }
    else if (_isSmartGit(hwnd)) {
        return _searchSiblingWindows(hwnd, _getSmartGitProjectName(hwnd))
    }
    return [hwnd]

}

updateGlobalVariables() {
    ; Re-generate the list of desktops and where we fit in that. We do this because
    ; the user may have switched desktops via some other means than the script.
    mapDesktopsFromRegistry()
}

global _desktopTT := TT("ClickTrough", "", "")
_desktopTT.SETWINDOWTHEME("")
_desktopTT.Font("S24 bold, Consolas")
_desktopTT.Color("White", "Red")
_desktopTT.SETMARGIN(30, 30, 30, 30)
_d_hideTT() {
    _desktopTT.Hide()
    SetTimer, _d_hideTT, Off
}

_notifyDesktopSwitched(oldDesktop, newDesktop) {
    Sleep 50
    oldDesktopName := _g_desktopIdToName[oldDesktop]
    newDesktopName := _g_desktopIdToName[newDesktop]
    caption = %newDesktopName%
    if (gStr_Len(caption) < 8) {
        dif := 8 - gStr_Len(caption)
        left := dif // 2
        right := dif - left
        caption := gStr_Repeat(" ", left) caption gStr_Repeat(" ", right)
    }
    _desktopTT.Text(caption)
    _desktopTT.Show("", A_ScreenWidth - 200, A_ScreenHeight - 200)
    SetTimer, _d_hideTT, 2000
}

switchDesktopByNumber(targetDesktop) {
    global CurrentDesktop, DesktopCount
    updateGlobalVariables()
    _switchDesktopToTarget(targetDesktop)
}

switchDesktopToLastOpened() {
    global CurrentDesktop, DesktopCount, LastOpenedDesktop
    updateGlobalVariables()
    _switchDesktopToTarget(LastOpenedDesktop)
}

switchDesktopToRight() {
    global CurrentDesktop, DesktopCount
    updateGlobalVariables()
    _switchDesktopToTarget(CurrentDesktop + 1)
}

switchDesktopToLeft() {
    global CurrentDesktop, DesktopCount
    updateGlobalVariables()
    _switchDesktopToTarget(CurrentDesktop - 1)
}

focusTheForemostWindow(targetDesktop) {
    foremostWindowId := getForemostWindowIdOnDesktop(targetDesktop)
    if isWindowNonMinimized(foremostWindowId) {
        WinActivate, ahk_id %foremostWindowId%
    }
}

isWindowNonMinimized(windowId) {
    WinGet MMX, MinMax, ahk_id %windowId%
    return MMX != -1
}

getForemostWindowIdOnDesktop(n) {
    n := n - 1 ; Desktops start at 0, while in script it's 1

    ; winIDList contains a list of windows IDs ordered from the top to the bottom for each desktop.
    WinGet winIDList, list
    Loop % winIDList {
        windowID := % winIDList%A_Index%
        windowIsOnDesktop := DllCall(IsWindowOnDesktopNumberProc, UInt, windowID, UInt, n)
        ; Select the first (and foremost) window which is in the specified desktop.
        if (windowIsOnDesktop == 1) {
            return windowID
        }
    }
}

_moveWindowToDesktop(hwnd, desktopNumber) {
    DllCall(MoveWindowToDesktopNumberProc, UInt, hwnd, UInt, desktopNumber - 1)
}

_moveWindowAndRelatedToDesktop(hwnd, desktopNumber) {
    for key, curHwnd in _getRelatedWindows(hwnd) {
        _moveWindowToDesktop(curHwnd, desktopNumber)
    }
}

MoveCurrentWindowToDesktop(desktopNumber, follow) {
    WinGet, activeHwnd, ID, A
    _moveWindowAndRelatedToDesktop(activeHwnd, desktopNumber)
    if (follow) {
        switchDesktopByNumber(desktopNumber)
    }
}

MoveCurrentWindowToRightDesktop(follow) {
    global CurrentDesktop, DesktopCount
    updateGlobalVariables()
    if (CurrentDesktop >= DesktopCount) {
        return
    }
    WinGet, activeHwnd, ID, A
    targetDesktop := CurrentDesktop + 1
    DllCall(MoveWindowToDesktopNumberProc, UInt, activeHwnd, UInt, targetDesktop - 1)
    if (follow) {
        _switchDesktopToTarget(targetDesktop)
    }
}

MoveCurrentWindowToLeftDesktop(follow) {
    global CurrentDesktop, DesktopCount
    updateGlobalVariables()
    if (CurrentDesktop == 1) {
        return
    }
    WinGet, activeHwnd, ID, A
    targetDesktop := CurrentDesktop == 1 ? DesktopCount : CurrentDesktop - 1
    DllCall(MoveWindowToDesktopNumberProc, UInt, activeHwnd, UInt, targetDesktop - 1)
    if (follow) {
        _switchDesktopToTarget(targetDesktop)
    }
}

;
; This function creates a new virtual desktop and switches to it
;
createVirtualDesktop() {
    global CurrentDesktop, DesktopCount
    Send, #^d
    DesktopCount++
    CurrentDesktop := DesktopCount
    OutputDebug, [create] desktops: %DesktopCount% current: %CurrentDesktop%
}

;
; This function deletes the current virtual desktop
;
deleteVirtualDesktop() {
    global CurrentDesktop, DesktopCount, LastOpenedDesktop
    Send, #^{F4}
    if (LastOpenedDesktop >= CurrentDesktop) {
        LastOpenedDesktop--
    }
    DesktopCount--
    CurrentDesktop--
    OutputDebug, [delete] desktops: %DesktopCount% current: %CurrentDesktop%
}
