#Requires AutoHotkey v2.0
#SingleInstance Force
; Copyright © 2026 Gornskew Enterprises
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU Affero General Public License as
; published by the Free Software Foundation, either version 3 of the
; License, or (at your option) any later version.  Distributed WITHOUT
; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.


; -------------------------------------------------------------------
; Global toggle: Emacs-like navigation in browsers ON/OFF
; -------------------------------------------------------------------
global EmacsNavMode := true  ; start enabled; toggle when using ttyd

F12:: {  ; Press F12 to toggle browser Emacs mode
    global EmacsNavMode
    EmacsNavMode := !EmacsNavMode
    ToolTip "Browser Emacs nav: " (EmacsNavMode ? "ON" : "OFF")
    SetTimer () => ToolTip(), -1000
}

; -------------------------------------------------------------------
; System-wide: Ctrl+Shift+V → Ctrl+V (paste)
; -------------------------------------------------------------------
^+v::Send "{Ctrl down}v{Ctrl up}"

; -------------------------------------------------------------------
; EDGE: Emacs-like navigation ONLY when EmacsNavMode is ON
; -------------------------------------------------------------------
#HotIf WinActive("ahk_exe msedge.exe") && EmacsNavMode

^p::Send "{Up}"
^n::Send "{Down}"
^f::Send "{Right}"
^b::Send "{Left}"
^d::Send "{Delete}"
^v::Send "{PgDn}"
!f::Send "{Ctrl down}{Right}{Ctrl up}"
!b::Send "{Ctrl down}{Left}{Ctrl up}"
^!f::Send "{Ctrl down}{Right}{Ctrl up}"
^!b::Send "{Ctrl down}{Left}{Ctrl up}"
!d::Send "{Ctrl down}{Delete}{Ctrl up}"
^a::Send "{Home}"
^e::Send "{End}"
^k::Send "{Shift down}{End}{Shift up}{Ctrl down}x{Ctrl up}"

#HotIf  ; end Edge scope

; -------------------------------------------------------------------
; Claude app: same idea
; -------------------------------------------------------------------
#HotIf WinActive("ahk_exe claude.exe") && EmacsNavMode

^p::Send "{Up}"
^n::Send "{Down}"
^f::Send "{Right}"
^b::Send "{Left}"
^d::Send "{Delete}"
^v::Send "{PgDn}"
!f::Send "{Ctrl down}{Right}{Ctrl up}"
!b::Send "{Ctrl down}{Left}{Ctrl up}"
^!f::Send "{Ctrl down}{Right}{Ctrl up}"
^!b::Send "{Ctrl down}{Left}{Ctrl up}"
!d::Send "{Ctrl down}{Delete}{Ctrl up}"
^a::Send "{Home}"
^e::Send "{End}"
^k::Send "{Shift down}{End}{Shift up}{Ctrl down}x{Ctrl up}"

#HotIf  ; end Claude scope

; -------------------------------------------------------------------
; Chrome: OPTIONAL Emacs nav for normal pages
;         (Again, only when EmacsNavMode is ON)
; -------------------------------------------------------------------
#HotIf WinActive("ahk_exe chrome.exe") && EmacsNavMode

^p::Send "{Up}"
^n::Send "{Down}"
^f::Send "{Right}"
^b::Send "{Left}"
^d::Send "{Delete}"
^v::Send "{PgDn}"
!f::Send "{Ctrl down}{Right}{Ctrl up}"
!b::Send "{Ctrl down}{Left}{Ctrl up}"
^!f::Send "{Ctrl down}{Right}{Ctrl up}"
^!b::Send "{Ctrl down}{Left}{Ctrl up}"
!d::Send "{Ctrl down}{Delete}{Ctrl up}"
^a::Send "{Home}"
^e::Send "{End}"
^k::Send "{Shift down}{End}{Shift up}{Ctrl down}x{Ctrl up}"

; Optional: block a few browser shortcuts even in Emacs mode
; (note: these will be blocked everywhere in Chrome, including ttyd)
; Comment them out if you want Emacs/ttyd to see these chords.

; ^+t::return     ; block reopen closed tab
; ^+n::return     ; block incognito
; ^+w::return     ; block close window

#HotIf  ; end Chrome scope
