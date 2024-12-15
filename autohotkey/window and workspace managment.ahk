;FROM https://superuser.com/questions/1685845/moving-current-window-to-another-desktop-in-windows-11-using-shortcut-keys

;#SETUP START
#SingleInstance force
ListLines 0
SendMode "Input" ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir A_ScriptDir ; Ensures a consistent starting directory.
KeyHistory 0
#WinActivateForce

ProcessSetPriority "H"

SetWinDelay -1
SetControlDelay -1

; Include the library
#Include ./VD.ah2
; VD.init() ; COMMENT OUT `static dummyStatic1 := VD.init()` if you don't want to init at start of script

; You should WinHide invisible programs that have a window.
try {
    WinHide "Malwarebytes Tray Application"
} catch {
}
;#SETUP END

VD.createUntil(3) ; Create until we have at least 3 virtual desktops

return

CapsLock::Esc ; Bind useless key to Usefull key

#Enter:: {
    activeWindow := WinExist("A")
    Run "wt.exe focus-tab"
    WinActivate("ahk_id " activeWindow)

} ; open windows terminal

Browser_Search:: { ; shutdown pc with random extra key on keyboard
    Shutdown(1)
}

#c:: Run "C:\Users\raj\AppData\Local\Programs\Microsoft VS Code\Code.exe" ; Open Visual Studio Code

#q:: WinClose("A") ; Close fucused Window

#f:: Run "firefox.exe" ; Open Firefox

#`:: { ; Focus Previous window
    winNumber := 0
    win := WinGetList()

    for index, winHandle in win {
        title := WinGetTitle(winHandle)
        proc := WinGetProcessName(winHandle)
        class := WinGetClass(winHandle)

        if (!(class ~= "i)Toolbar|#32770") && title != ""
        && (title != "Program Manager" || proc != "Explorer.exe")) {
            winNumber++
        }

        if (winNumber = 2) {
            WinActivate(winHandle)
            break
        }
    }
    return
}

#!x:: { ; Close All windows alltogether on desktop
    closeAll('ahk_class CabinetWClass') ;
}

closeAll(winTitle) {
    for hWnd in WinGetList(winTitle)
        WinClose hWnd
}

#!Left:: { ; Move window to left workspace
    currentDesktop := VD.getCurrentDesktopNum()
    totalDesktops := VD.getCount()

    ; Loop around to the last desktop if at the first one
    previousDesktop := (currentDesktop = 1) ? totalDesktops : currentDesktop - 1
    activeWindow := WinExist("A")
    VD.goToDesktopNum(previousDesktop)
    VD.MoveWindowToDesktopNum("ahk_id " activeWindow, previousDesktop)
    WinActivate("ahk_id " activeWindow) ; Once in a while it's not active
}

#!Right:: { ; Move window to right workspace
    currentDesktop := VD.getCurrentDesktopNum()
    totalDesktops := VD.getCount()

    ; Loop around to the first desktop if at the last one
    nextDesktop := (currentDesktop = totalDesktops) ? 1 : currentDesktop + 1
    activeWindow := WinExist("A")
    VD.goToDesktopNum(nextDesktop)
    VD.MoveWindowToDesktopNum("ahk_id " activeWindow, nextDesktop)
    WinActivate("ahk_id " activeWindow)
}
