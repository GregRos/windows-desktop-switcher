#SingleInstance Force ; The script will Reload if launched while already running
#NoEnv ; Recommended for performance and compatibility with future AutoHotkey releases
SetWorkingDir %A_ScriptDir% ; Ensures a consistent starting directory
SendMode Input ; Recommended for new scripts due to its superior speed and reliability
SetCapsLockState, AlwaysOff
#MaxThreadsPerHotkey, 4

#Include _implementation.ahk
#include <gutils>
Menu, tray, NoStandard
Menu, Tray, Icon, images\icon.ico
Menu, Tray, Tip, DesktopSwitcher!
Menu, Tray, Add, DesktopSwitcher Help, OnHelp
Menu, Tray, Default, DesktopSwitcher Help
Menu, Tray, Add, Exit, OnClickExit

ComObjArrayToString(arr) {
    res := ""
    for x in arr {
        res .= chr(x)
    }
    return res
}
OnClickExit() {
    ExitApp
}
OnHelp() {
    Run, % A_ScriptDir "\HELP.html"
}

GetHotkeyMode() {
    if (!GetKeyState("CapsLock", "P")) {
        return ""
    }
    if (GetKeyState("RButton", "P")) {
        return "CR"
    } else if (GetKeyState("LButton", "P")) {
        return "CL"
    } else {
        return "C"
    }
}

#if GetHotkeyMode() != ""
    RButton::Return
LButton::Return

#if GetHotkeyMode() = "C"
    1::switchDesktopByNumber(1)
2::switchDesktopByNumber(2)
3::switchDesktopByNumber(3)
4::switchDesktopByNumber(4)
5::switchDesktopByNumber(5)
d::switchDesktopToRight()
a::switchDesktopToLeft()
tab::switchDesktopToLastOpened()
#if GetHotkeyMode() = "CL"
    d::MoveCurrentWindowToRightDesktop(True)
a::MoveCurrentWindowToLeftDesktop(True)
1::MoveCurrentWindowToDesktop(1, True)
2::MoveCurrentWindowToDesktop(2, True)
3::MoveCurrentWindowToDesktop(3, True)
4::MoveCurrentWindowToDesktop(4, True)
5::MoveCurrentWindowToDesktop(5, True)
#if GetHotkeyMode() = "CR"
    d::MoveCurrentWindowToRightDesktop(False)
a::MoveCurrentWindowToLeftDesktop(False)
1::MoveCurrentWindowToDesktop(1, False)
2::MoveCurrentWindowToDesktop(2, False)
3::MoveCurrentWindowToDesktop(3, False)
4::MoveCurrentWindowToDesktop(4, False)
5::MoveCurrentWindowToDesktop(5, False)
#if
