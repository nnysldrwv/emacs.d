' launch-emacs.vbs — Start Emacs daemon (if not running) then open a frame via emacsclient.
' Taskbar/Start Menu shortcut should point to this script.

Dim WshShell, fso, msys2Bin, emacsclient, runemacs, emacs
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

msys2Bin = "C:\Users\fengxing.chen\scoop\apps\msys2\current\mingw64\bin"
emacsclient = msys2Bin & "\emacsclientw.exe"
runemacs    = msys2Bin & "\runemacs.exe"
emacs       = msys2Bin & "\emacs.exe"

' Ensure mingw64/bin is in PATH so Emacs can load tree-sitter and its deps (wasmtime.dll etc.)
Dim currentPath
currentPath = WshShell.Environment("PROCESS")("PATH")
If InStr(currentPath, msys2Bin) = 0 Then
    WshShell.Environment("PROCESS")("PATH") = msys2Bin & ";" & currentPath
End If

' Try emacsclient first — if daemon is already running, this returns instantly
Dim ret
ret = WshShell.Run("""" & emacsclient & """ -c -n -a """"", 0, True)

' emacsclient -a "" will auto-start daemon if not running,
' but on some builds that may fail silently. Fallback:
If ret <> 0 Then
    ' Start daemon in background
    WshShell.Run """" & runemacs & """ --daemon", 0, False
    WScript.Sleep 3000
    ' Now connect
    WshShell.Run """" & emacsclient & """ -c -n", 0, False
End If
