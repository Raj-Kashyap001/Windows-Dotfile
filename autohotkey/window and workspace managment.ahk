;===============================================================================
; Windows 11 Virtual Desktop Manager and Hotkeys
;===============================================================================

;-------------------------------------------------------------------------------
; INITIALIZATION AND SETUP
;-------------------------------------------------------------------------------
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
        ; Open Activiry Tab
        loop {
            if !(IsCorner("TopLeft")) {
                break  ; Exits loop when mouse is no longer in the corner
            }
        }
    }

    ; ; Show Action Center
    ; if (IsCorner("TopRight")) {
    ;     Send("{LWin down}{a down}")
    ;     Send("{LWin up}{a up}")
    ;     Loop {
    ;         if !(IsCorner("TopRight")) {
    ;             break  ; Exits loop when mouse is no longer in the corner
    ;         }
    ;     }
    ; }

    ; Press Windows key
    if (IsCorner("BottomLeft")) {
        Send("{LWin down}")
        Send("{LWin up}")
        loop {
            if !(IsCorner("BottomLeft")) {
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
    activeWindow := WinExist("A")
    Run "wt.exe focus-tab"
    WinActivate("ahk_id " activeWindow)
}

#`:: {                                 ; Win + `: Focus previous window
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
}

;-------------------------------------------------------------------------------
; Window Resize Functions
;-------------------------------------------------------------------------------

; Get the monitor working area dimensions for active window
GetMonitorWorkArea(winTitle) {
    MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
    return { left: left, top: top, right: right, bottom: bottom }
}

; Constants for resize increments (in pixels)
RESIZE_INCREMENT := 50

; Win + Shift + Right: Increase window width
#+Right:: {
    ; Get active window
    if (winHandle := WinExist("A")) {
        ; Get current window position and size
        WinGetPos(&x, &y, &width, &height, winHandle)

        ; Get monitor working area
        workArea := GetMonitorWorkArea(winHandle)

        ; Calculate new width
        newWidth := Min(width + RESIZE_INCREMENT, workArea.right - workArea.left)

        ; Calculate new X position to keep window centered
        newX := Max(workArea.left, x - (RESIZE_INCREMENT / 2))

        ; Ensure window doesn't go off screen
        if (newX + newWidth > workArea.right)
            newX := workArea.right - newWidth

        ; Move and resize window
        WinMove(newX, y, newWidth, height, winHandle)
    }
}

; Win + Shift + Left: Decrease window width
#+Left:: {
    ; Get active window
    if (winHandle := WinExist("A")) {
        ; Get current window position and size
        WinGetPos(&x, &y, &width, &height, winHandle)

        ; Minimum width limit
        minWidth := 200

        ; Calculate new width
        newWidth := Max(width - RESIZE_INCREMENT, minWidth)

        ; Calculate new X position to keep window centered
        newX := x + ((width - newWidth) / 2)

        ; Move and resize window
        WinMove(newX, y, newWidth, height, winHandle)
    }
}

;-------------------------------------------------------------------------------
; Half-Width Window Tiling (Hyprland-style)
;-------------------------------------------------------------------------------

#t:: {
    ; Get monitor work area (exact screen boundaries)
    MonitorGetWorkArea(MonitorGetPrimary(), &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
    monitorWidth := monitorRight - monitorLeft
    monitorHeight := monitorBottom - monitorTop

    ; Gap corrections
    outerGap := 0
    innerGapX := 0
    innerGapY := 5
    ; Correct the monitor dimensions for the outer gap
    monitorLeft += outerGap
    monitorTop += outerGap
    monitorWidth -= 2 * outerGap
    monitorHeight -= 2 * outerGap

    ; Get list of visible windows
    windows := []
    for hwnd in WinGetList() {
        title := WinGetTitle(hwnd)

        ; Skip taskbar and empty titles, but include explorer windows
        if (title
            && !InStr(title, "Program Manager")
            && WinGetClass(hwnd) != "Shell_TrayWnd"
            && WinExist("ahk_id " hwnd)
            && WinGetStyle(hwnd) & 0x10000000) ; Only visible windows
        {
            windows.Push(hwnd)
        }
    }

    windowCount := windows.Length

    ; If no windows to tile, exit
    if (windowCount = 0)
        return

    ; Calculate half width (monitor width divided by 2, adjust for inner gap)
    halfWidth := (monitorWidth + innerGapX) // 2

    ; Align windows
    if (windowCount = 1) {
        ; Single window: Maximize to entire monitor work area
        WinRestore("ahk_id " windows[1])
        WinMove(monitorLeft, monitorTop, monitorWidth, monitorHeight, "ahk_id " windows[1])
    } else if (windowCount = 2) {
        ; Two windows: Left and right halves
        WinRestore("ahk_id " windows[1])
        WinMove(monitorLeft, monitorTop, halfWidth, monitorHeight, "ahk_id " windows[1])

        ; Adjust second window
        WinRestore("ahk_id " windows[2])
        WinMove(monitorLeft + halfWidth - innerGapX, monitorTop, halfWidth, monitorHeight, "ahk_id " windows[2])
    } else {
        ; More than two windows: Left half for first, right half stacked vertically
        WinRestore("ahk_id " windows[1])
        WinMove(monitorLeft, monitorTop, halfWidth, monitorHeight, "ahk_id " windows[1])

        ; Secondary windows in right half, stacked vertically
        secondaryHeight := (monitorHeight + innerGapY * (windowCount - 2)) // (windowCount - 1)
        index := 2
        while (index <= windowCount) {
            WinRestore("ahk_id " windows[index])

            ; Adjust and stack secondary windows vertically
            WinMove(
                monitorLeft + halfWidth - innerGapX,                       ; x position
                monitorTop + ((index - 2) * (secondaryHeight - innerGapY)), ; y position
                halfWidth,                                                ; width
                secondaryHeight,                                          ; height
                "ahk_id " windows[index]
            )
            index++
        }
    }
}

;-------------------------------------------------------------------------------
; VIRTUAL DESKTOP MANAGEMENT
;-------------------------------------------------------------------------------
#!Left:: {                             ; Win + Alt + Left: Move window to left desktop
    currentDesktop := VD.getCurrentDesktopNum()
    totalDesktops := VD.getCount()

    previousDesktop := (currentDesktop = 1) ? totalDesktops : currentDesktop - 1
    activeWindow := WinExist("A")
    VD.goToDesktopNum(previousDesktop)
    VD.MoveWindowToDesktopNum("ahk_id " activeWindow, previousDesktop)
    WinActivate("ahk_id " activeWindow)
}

#!Right:: {                            ; Win + Alt + Right: Move window to right desktop
    currentDesktop := VD.getCurrentDesktopNum()
    totalDesktops := VD.getCount()

    nextDesktop := (currentDesktop = totalDesktops) ? 1 : currentDesktop + 1
    activeWindow := WinExist("A")
    VD.goToDesktopNum(nextDesktop)
    VD.MoveWindowToDesktopNum("ahk_id " activeWindow, nextDesktop)
    WinActivate("ahk_id " activeWindow)
}

#+x:: {  ; Win+Shift+X to close all windows
    CloseAllWindows()
}

;-------------------------------------------------------------------------------
; UTILITY FUNCTIONS
;-------------------------------------------------------------------------------
closeAll(winTitle) {                   ; Function to close all windows of a type
    for hWnd in WinGetList(winTitle)
        WinClose hWnd
}

CloseAllWindows() {
    for hwnd in WinGetList() {
        ; Get window information
        title := WinGetTitle(hwnd)
        process := WinGetProcessName(hwnd)

        ; Skip system windows and empty titles
        if (title != ""
            && process != "explorer.exe"  ; Skip Explorer/Desktop
            && !WinExist("ahk_class Shell_TrayWnd ahk_id " hwnd)  ; Skip Taskbar
            && !WinExist("ahk_class Windows.UI.Core.CoreWindow ahk_id " hwnd))  ; Skip Modern UI
        {
            WinClose(hwnd)
        }

    }
}

; CheckMousePosition() {                  ; Hot corner detection function
;     global timeRequired, startTime, isTracking

;     ; Get the mouse position
;     MouseGetPos(&currentX, &currentY)

;     ; Check if the mouse is at the top-left corner (0, 0)
;     if (currentX = 0 && currentY = 0) {
;         if (!isTracking) {
;             startTime := A_TickCount
;             isTracking := true
;         } else {
;             if (A_TickCount - startTime >= timeRequired) {
;                 isTracking := false
;                 ; Trigger Task View
;                 Run("explorer.exe shell:::{3080F90E-D7AD-11D9-BD98-0000947B0257}")
;                 Sleep 500
;             }
;         }
;     } else {
;         isTracking := false
;     }
; }
