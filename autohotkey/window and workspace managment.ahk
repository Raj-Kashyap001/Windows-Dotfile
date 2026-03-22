;===============================================================================
; Windows 10/11 Virtual Desktop Manager and Hotkeys
;===============================================================================

;-------------------------------------------------------------------------------
; INITIALIZATION AND SETUP
;-------------------------------------------------------------------------------

; Error Handler Configuration
#Warn All, Off  ; Disable all warnings

#SingleInstance force                    ; Replace any existing instance
ListLines 0                             ; Disable line logging for performance
SendMode "Input"                        ; Use faster and more reliable input mode
SetWorkingDir A_ScriptDir              ; Set consistent working directory
KeyHistory 0                            ; Disable key history
#WinActivateForce                       ; Force window activation

; Set high priority for this script
ProcessSetPriority "H"

; Disable window operation delays
SetWinDelay -1
SetControlDelay -1

; Include virtual desktop management library
#Include ./VD.ah2

;-------------------------------------------------------------------------------
; MAIN EXECUTION WITH ERROR HANDLING
;-------------------------------------------------------------------------------

RestartScript(delay := 5000) {
    Sleep delay
    Run A_ScriptFullPath
    ExitApp
}

try {
    ;-------------------------------------------------------------------------------
    ; HOT CORNER CONFIGURATION
    ;-------------------------------------------------------------------------------
    ; Define hot corner parameters
    cornerSize := 1                         ; Detection area size in pixels
    cornerX := 0                           ; X coordinate of hot corner
    cornerY := 0                           ; Y coordinate of hot corner

    ; Hot corner timing variables
    timeRequired := 0                       ; Time required to trigger (milliseconds)
    startTime := 0                         ; Track when mouse enters corner
    isTracking := false                    ; Track if mouse is in corner

    ;-------------------------------------------------------------------------------
    ; STARTUP OPERATIONS
    ;-------------------------------------------------------------------------------
    ; Hide system tray applications
    try {
        WinHide "Malwarebytes Tray Application"
    } catch {
    }

    ; Ensure minimum number of virtual desktops
    VD.createUntil(3)                      ; Create at least 3 virtual desktops

    ; Start hot corner monitoring
    SetTimer(HotCorners, 10)  ; HotCorners is the name of the timer, will be reset every 0 seconds until the process is killed

    ;-------------------------------------------------------------------------------
    ; BASIC KEYBOARD REMAPPING
    ;-------------------------------------------------------------------------------
    CapsLock::Esc                          ; Remap Caps Lock to Escape
    Browser_Search:: Shutdown(1)            ; Use browser search key to trigger shutdown

    ;-------------------------------------------------------------------------------
    ; HOT CORNERS
    ;-------------------------------------------------------------------------------

    HotCorners() {  ; Timer content
        CoordMode("Mouse", "Screen")  ; Coordinate mode - coordinates will be passed to mouse-related functions, with coords relative to the entire screen
        IsCorner(cornerID) {
            if !WinExist("Program Manager") {  ; Check if the desktop window exists
                RestartScript()  ; Restart the script if the window is null
                return false
            }

            WinGetPos(&X, &Y, &Xmax, &Ymax, "Program Manager")  ; Get desktop size
            MouseGetPos(&MouseX, &MouseY)  ; Function MouseGetPos retrieves the current position of the mouse cursor
            T := 5  ; Adjust tolerance value (pixels to corner) if desired

            ; Boolean stores whether the mouse cursor is in the corner
            CornerTopLeft := (MouseY < T and MouseX < T)
            CornerTopRight := (MouseY < T and MouseX > Xmax - T)
            CornerBottomLeft := (MouseY > Ymax - T and MouseX < T)
            CornerBottomRight := (MouseY > Ymax - T and MouseX > Xmax - T)

            if (cornerID = "TopLeft") {
                return CornerTopLeft
            } else if (cornerID = "TopRight") {
                return CornerTopRight
            } else if (cornerID = "BottomLeft") {
                return CornerBottomLeft
            } else if (cornerID = "BottomRight") {
                return CornerBottomRight
            }
        }

        ; Show Task View (Open Apps Overview)
        if (IsCorner("TopLeft")) {
            Send("{LWin down}{Tab down}")
            Send("{LWin up}{Tab up}")
            ; Open Activity Tab
            loop {
                if !(IsCorner("TopLeft")) {
                    break  ; Exits loop when mouse is no longer in the corner
                }
            }
        }
    }

    ;-------------------------------------------------------------------------------
    ; APPLICATION LAUNCHER SHORTCUTS
    ;-------------------------------------------------------------------------------
    #c:: Run "C:\Users\raj\AppData\Local\Programs\Microsoft VS Code\Code.exe"    ; Win + C: Launch VS Code
    #f:: Run "firefox.exe"                                                       ; Win + F: Launch Firefox

    ;-------------------------------------------------------------------------------
    ; WINDOW MANAGEMENT SHORTCUTS
    ;-------------------------------------------------------------------------------
    #q:: WinClose("A")                     ; Win + Q: Close active window

    #Enter:: {                             ; Win + Enter: Focus Windows Terminal
        try {
            activeWindow := WinExist("A")
            Run "wt.exe"
            if (activeWindow) {
                try {
                    WinActivate("ahk_id " activeWindow)
                } catch {
                    ; Window no longer exists, ignore
                }
            }
        } catch {
            ; Failed to get active window or run wt.exe
        }
    }

    #`:: {                                 ; Win + `: Focus previous window
        try {
            winNumber := 0
            win := WinGetList()
            for index, winHandle in win {
                try {
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
                } catch {
                    ; Window no longer exists, continue to next
                    continue
                }
            }
        } catch {
            ; Failed to get window list
        }
    }

    ;-------------------------------------------------------------------------------
    ; WINDOW WIDTH RESIZING (Hyprland-style: center-anchored)
    ; Win + [  =>  shrink width by 10% of current width
    ; Win + ]  =>  grow width by 10% of current width
    ;
    ; Skipped for:
    ;   - No focused window
    ;   - Dialog boxes (#32770)
    ;   - Maximized / minimized windows
    ;   - Windows that refuse WinMove (e.g. some UWP apps)
    ;-------------------------------------------------------------------------------

    IsResizableWindow(hwnd) {
        ; Reject dialog boxes
        class := WinGetClass("ahk_id " hwnd)
        if (class = "#32770")
            return false

        ; Reject minimized or maximized windows
        minMax := WinGetMinMax("ahk_id " hwnd)
        if (minMax != 0)   ; 1 = maximized, -1 = minimized
            return false

        return true
    }

    ResizeWidth(direction) {
        ; direction: +1 to grow, -1 to shrink
        try {
            hwnd := WinExist("A")
            if (!hwnd)
                return

            if (!IsResizableWindow(hwnd))
                return

            ; Get current window geometry
            WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " hwnd)

            ; Get screen width to determine which half the window is on
            screenW := SysGet(78)   ; SM_CXVIRTUALSCREEN (full virtual screen width)
            screenX := SysGet(76)   ; SM_XVIRTUALSCREEN  (left edge of virtual screen)

            ; Use the window's horizontal center to decide which side it hugs
            winCenterX := winX + winW // 2
            screenMidX := screenX + screenW // 2

            ; Compute delta: 10% of current width, minimum 1px
            delta := Round(winW * 0.10)
            if (delta < 1)
                delta := 1

            newW := winW + (direction * delta)
            if (newW < 100)
                newW := 100

            if (winCenterX >= screenMidX) {
                ; Window is on the RIGHT half — anchor right edge, adjust from left
                ; Flip direction: ] grows leftward (newX decreases), [ shrinks rightward (newX increases)
                newW := winW + (-direction * delta)
                if (newW < 100)
                    newW := 100
                rightEdge := winX + winW
                newX := rightEdge - newW
                if (newX < screenX)
                    newX := screenX
            } else {
                ; Window is on the LEFT half — anchor left edge, adjust from right
                newX := winX
            }

            WinMove(newX, winY, newW, winH, "ahk_id " hwnd)
        } catch {
            ; Window no longer exists or cannot be resized — silently ignore
        }
    }

    #[:: ResizeWidth(-1)                   ; Win + [: Shrink window width
    #]:: ResizeWidth(+1)                   ; Win + ]: Grow window width

    ;-------------------------------------------------------------------------------
    ; VIRTUAL DESKTOP MANAGEMENT
    ;-------------------------------------------------------------------------------
    #!Left:: {                             ; Win + Alt + Left: Move window to left desktop
        try {
            currentDesktop := VD.getCurrentDesktopNum()
            totalDesktops := VD.getCount()

            previousDesktop := (currentDesktop = 1) ? totalDesktops : currentDesktop - 1
            activeWindow := WinExist("A")
            
            if (activeWindow) {
                VD.goToDesktopNum(previousDesktop)
                try {
                    VD.MoveWindowToDesktopNum("ahk_id " activeWindow, previousDesktop)
                    WinActivate("ahk_id " activeWindow)
                } catch {
                    ; Window no longer exists or cannot be moved
                }
            }
        } catch {
            ; Failed to get desktop info or move window
        }
    }

    #!Right:: {                            ; Win + Alt + Right: Move window to right desktop
        try {
            currentDesktop := VD.getCurrentDesktopNum()
            totalDesktops := VD.getCount()

            nextDesktop := (currentDesktop = totalDesktops) ? 1 : currentDesktop + 1
            activeWindow := WinExist("A")
            
            if (activeWindow) {
                VD.goToDesktopNum(nextDesktop)
                try {
                    VD.MoveWindowToDesktopNum("ahk_id " activeWindow, nextDesktop)
                    WinActivate("ahk_id " activeWindow)
                } catch {
                    ; Window no longer exists or cannot be moved
                }
            }
        } catch {
            ; Failed to get desktop info or move window
        }
    }

    #+x:: {  ; Win+Shift+X to close all windows
        try {
            CloseAllWindows()
        } catch {
            ; Failed to close windows
        }
    }
} catch {
    ; Log the error (optional)
    FileAppend("Error occurred: " Error " at " A_Now "`n", A_ScriptDir "\error.log")

    ; Restart the script after a delay
    RestartScript()
}

;-------------------------------------------------------------------------------
; WIN + NUMBER TO SWITCH WORKSPACES (Overrides Taskbar Apps)
;-------------------------------------------------------------------------------
Loop 9 {
	Hotkey("#" . A_Index, (hk) => (
		num := Integer(SubStr(hk, 2)),
		VD.createUntil(num),
		VD.goToDesktopNum(num)
	))
}
	
;-------------------------------------------------------------------------------
; WIN + SHIFT + NUMBER TO MOVE WINDOW TO WORKSPACE AND FOLLOW
;-------------------------------------------------------------------------------
Loop 9 {
    Hotkey("#+" . A_Index, MoveWindowAndFollow)
}

MoveWindowAndFollow(hk) {
    ; Extract the number from the hotkey string (e.g., "#+3" -> 3)
    num := Integer(SubStr(hk, 3))
    
    ; Identify the active window
    activeWin := WinExist("A")
    
    ; Proceed only if a window is focused
    if (activeWin) {
        try {
            ; Ensure the target desktop exists
            VD.createUntil(num)
            
            ; Move the window to the target desktop
            VD.MoveWindowToDesktopNum("ahk_id " activeWin, num)
            
            ; Switch view to that desktop
            VD.goToDesktopNum(num)
            
            ; Refocus the window
            WinActivate("ahk_id " activeWin)
        } catch {
            ; Do nothing if move fails
        }
    }
}
