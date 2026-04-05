' start-daemon.vbs ? Start Emacs daemon silently at logon
Set WshShell = CreateObject("WScript.Shell")
Dim env
Set env = WshShell.Environment("Process")
env("PATH") = "C:\Users\fengxing.chen\scoop\apps\msys2\current\mingw64\bin;" & env("PATH")
WshShell.Run """C:\Users\fengxing.chen\scoop\apps\msys2\current\mingw64\bin\runemacs.exe"" --daemon", 0, False
