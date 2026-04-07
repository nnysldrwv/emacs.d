# register-org-protocol.ps1
# 在 Windows 注册表中注册 org-protocol:// 协议，
# 使浏览器点击 org-protocol:// 链接时自动调用 emacsclientw.exe
#
# 使用方式（管理员不是必须，当前用户注册即可）：
#   pwsh -File "C:\Users\fengxing.chen\.emacs.d\scripts\register-org-protocol.ps1"

$emacsclient = "C:\Users\fengxing.chen\scoop\apps\msys2\current\mingw64\bin\emacsclientw.exe"

if (-not (Test-Path $emacsclient)) {
    Write-Error "emacsclientw.exe not found at: $emacsclient"
    exit 1
}

$regBase = "HKCU:\Software\Classes\org-protocol"

# 创建协议根键
New-Item -Path $regBase -Force | Out-Null
Set-ItemProperty -Path $regBase -Name "(Default)"       -Value "URL:Org Protocol"
Set-ItemProperty -Path $regBase -Name "URL Protocol"    -Value ""

# 创建图标（可选，用 Emacs 图标）
New-Item -Path "$regBase\DefaultIcon" -Force | Out-Null
Set-ItemProperty -Path "$regBase\DefaultIcon" -Name "(Default)" -Value "$emacsclient,0"

# 注册命令：emacsclientw.exe -n "%1"
New-Item -Path "$regBase\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path "$regBase\shell\open\command" -Name "(Default)" `
    -Value "`"$emacsclient`" -n `"%1`""

Write-Host "✅ org-protocol registered successfully."
Write-Host "   Handler: $emacsclient"
Write-Host ""
Write-Host "Test with (run in browser address bar or PowerShell):"
Write-Host "   org-protocol://capture?template=pl&url=https%3A%2F%2Fexample.com&title=Test"
