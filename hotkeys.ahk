#SingleInstance Force ; The script will Reload if launched while already running
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases
#KeyHistory 0 ; Ensures user privacy when debugging is not needed
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability
#Include desktop_switcher.ahk

*CapsLock::Return
#if !GetKeyState("LButton", "P")
CapsLock & 1::switchDesktopByNumber(1)
CapsLock & 2::switchDesktopByNumber(2)
CapsLock & 3::switchDesktopByNumber(3)
CapsLock & 4::switchDesktopByNumber(4)
CapsLock & 5::switchDesktopByNumber(5)

CapsLock & d::switchDesktopToRight()
CapsLock & a::switchDesktopToLeft()
CapsLock & tab::switchDesktopToLastOpened()
#if
#if GetKeyState("LButton", "P")
CapsLock & d::MoveCurrentWindowToRightDesktop(True)
CapsLock & a::MoveCurrentWindowToLeftDesktop(True)
CapsLock & 1::MoveCurrentWindowToDesktop(1, True)
CapsLock & 2::MoveCurrentWindowToDesktop(2, True)
CapsLock & 3::MoveCurrentWindowToDesktop(3, True)
CapsLock & 4::MoveCurrentWindowToDesktop(4, True)
CapsLock & 5::MoveCurrentWindowToDesktop(5, True)
#if
