; Globals
DesktopCount := 4        ; Windows starts with 2 desktops at boot
CurrentDesktop := 1      ; Desktop count is 1-indexed (Microsoft numbers them this way)
PreviousDesktop := 1     ; Number of previous desktop

;
; This function examines the registry to build an accurate list of the current virtual desktops and which one we're currently on.
; Current desktop UUID appears to be in HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SessionInfo\1\VirtualDesktops
; List of desktops appears to be in HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops
;
mapDesktopsFromRegistry() {
    global DesktopCount, CurrentDesktop, PreviousDesktop

    ; Get the current desktop UUID. Length should be 32 always, but there's no guarantee this couldn't change in a later Windows release so we check.
    IdLength := 32
    SessionId := getSessionId()
    if (SessionId) {
        RegRead, CurrentDesktopId, HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SessionInfo\%SessionId%\VirtualDesktops, CurrentVirtualDesktop
        if (CurrentDesktopId) {
            IdLength := StrLen(CurrentDesktopId)
        }
    }

    ; Get a list of the UUIDs for all virtual desktops on the system
    RegRead, DesktopList, HKEY_CURRENT_USER, SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops, VirtualDesktopIDs
    if (DesktopList) {
        DesktopListLength := StrLen(DesktopList)
        ; Figure out how many virtual desktops there are
        DesktopCount := DesktopListLength / IdLength
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

        ; Break out if we find a match in the list. If we didn't find anything, keep the
        ; old guess and pray we're still correct :-D.
        if (DesktopIter = CurrentDesktopId) {
            if (CurrentDesktop <> i + 1) {
                CurrentDesktop := i + 1
            }
            OutputDebug, Current desktop number is %CurrentDesktop% with an ID of %DesktopIter%.
            break
        }
        i++
    }
}

;
; This functions finds out ID of current session.
;
getSessionId()
{
    ProcessId := DllCall("GetCurrentProcessId", "UInt")
    if ErrorLevel {
        OutputDebug, Error getting current Process Id: %ErrorLevel%
        return
    }
    OutputDebug, Current Process Id: %ProcessId%

    DllCall("ProcessIdToSessionId", "UInt", ProcessId, "UInt*", SessionId)
    if ErrorLevel {
        OutputDebug, Error getting Session Id: %ErrorLevel%
        return
    }
    OutputDebug, Current Session Id: %SessionId%
    return SessionId
}

;
; This function switches to the desktop number provided.
;
switchDesktopByNumber(targetDesktop, map := true)
{
    global DesktopCount, CurrentDesktop, PreviousDesktop

    ; Re-generate the list of desktops and where we fit in that. We do this because
    ; the user may have switched desktops via some other means than the script.
    if (map) {
        mapDesktopsFromRegistry()
    }

    ; Don't switch to current desktop
    if (targetDesktop = CurrentDesktop) {
        return
    }

    ; Don't attempt to switch to an invalid desktop
    if (targetDesktop > DesktopCount || targetDesktop < 1) {
        OutputDebug, [invalid] target: %targetDesktop% current: %CurrentDesktop%
        return
    }

    ; Open task view and wait for it to become active
    Loop
    {
        OutputDebug, Opening Task View
        Send, #{Tab}
        OutputDebug, Waiting for Task View
        WinWaitActive, ahk_class MultitaskingViewFrame,, 0.2
        if ErrorLevel {
            OutputDebug, Timed out waiting for task view
        }
        else {
            break
        }
    }

    ; Focus on desktops
    Send, {Tab}

    ; Page through desktops without opening any
    if (targetDesktop > 1) {
        targetDesktop--
        Send, {Right %targetDesktop%}
        targetDesktop++
    }

    ; Finally, select the desktop
    Send, {Enter}
    PreviousDesktop := CurrentDesktop
    CurrentDesktop := targetDesktop
}

;
; This function switches to last desktop where you were before
;
switchToPreviousDesktop()
{
    global PreviousDesktop
    mapDesktopsFromRegistry()
    switchDesktopByNumber(PreviousDesktop, false)
}

;
; This function creates a new virtual desktop and switches to it
;
createVirtualDesktop()
{
    global DesktopCount, CurrentDesktop, PreviousDesktop
    Send, #^d
    DesktopCount++
    PreviousDesktop := CurrentDesktop
    CurrentDesktop := DesktopCount
    OutputDebug, [create] desktops: %DesktopCount% current: %CurrentDesktop%
}

;
; This function deletes the current virtual desktop
;
deleteVirtualDesktop()
{
    global DesktopCount, CurrentDesktop, PreviousDesktop
    Send, #^{F4}
    DesktopCount--
    CurrentDesktop--
    PreviousDesktop := CurrentDesktop
    OutputDebug, [delete] desktops: %DesktopCount% current: %CurrentDesktop%
}

;
; This function toggles layer setting of current window
;
toggleAlwaysOnTop()
{
    hwnd := WinExist("A")
    WinSet, AlwaysOnTop, Toggle, ahk_id %hwnd%
}

; Main
mapDesktopsFromRegistry()
PreviousDesktop := CurrentDesktop
OutputDebug, [loading] desktops: %DesktopCount% current: %CurrentDesktop%

; User config!
; This section binds the key combo to the switch/create/delete actions
!1::switchDesktopByNumber(1)
!2::switchDesktopByNumber(2)
!3::switchDesktopByNumber(3)
!4::switchDesktopByNumber(4)
!5::switchDesktopByNumber(5)
!6::switchDesktopByNumber(6)
!7::switchDesktopByNumber(7)
!8::switchDesktopByNumber(8)
!9::switchDesktopByNumber(9)
!`::switchToPreviousDesktop()
^#a::toggleAlwaysOnTop()
