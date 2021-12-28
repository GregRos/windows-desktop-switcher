#SingleInstance Force ; The script will Reload if launched while already running
#NoEnv ; Recommended for performance and compatibility with future AutoHotkey releases
SetWorkingDir %A_ScriptDir% ; Ensures a consistent starting directory
SendMode Input ; Recommended for new scripts due to its superior speed and reliability
SetCapsLockState, AlwaysOff

#Include _implementation.ahk
Menu, tray, NoStandard
Menu, Tray, Icon, images\icon.ico
Menu, Tray, Tip, DesktopSwitcher!
Menu, Tray, Add, DesktopSwitcher Help, OnHelp
Menu, Tray, Default, DesktopSwitcher Help
Menu, Tray, Add, Exit, OnExit

OnExit() {
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
#MaxThreadsPerHotkey, 4

#if GetHotkeyMode() != ""
RButton::Return
LButton::Return
#if
    #if GetHotkeyMode() = "C"
    1::switchDesktopByNumber(1)
2::switchDesktopByNumber(2)
3::switchDesktopByNumber(3)
4::switchDesktopByNumber(4)
5::switchDesktopByNumber(5)
d::switchDesktopToRight()
a::switchDesktopToLeft()
tab::switchDesktopToLastOpened()
#if
    #if GetHotkeyMode() = "CL"
    d::MoveCurrentWindowToRightDesktop(True)
a::MoveCurrentWindowToLeftDesktop(True)
1::MoveCurrentWindowToDesktop(1, True)
2::MoveCurrentWindowToDesktop(2, True)
3::MoveCurrentWindowToDesktop(3, True)
4::MoveCurrentWindowToDesktop(4, True)
5::MoveCurrentWindowToDesktop(5, True)
#if
    #if GetHotkeyMode() = "CR"
    d::MoveCurrentWindowToRightDesktop(False)
a::MoveCurrentWindowToLeftDesktop(False)
1::MoveCurrentWindowToDesktop(1, False)
2::MoveCurrentWindowToDesktop(2, False)
3::MoveCurrentWindowToDesktop(3, False)
4::MoveCurrentWindowToDesktop(4, False)
5::MoveCurrentWindowToDesktop(5, False)
#if
