#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Verifies that the Windows VM is properly configured for Ansible/WinRM connectivity.

.DESCRIPTION
    This script checks all the configuration that should have been applied by the
    autounattend.xml during Windows installation. Run this on the Windows VM to
    confirm everything is set up correctly for the compliance automation collection.

.EXAMPLE
    .\Verify-WinRMSetup.ps1

.NOTES
    Author: ansible_tmm.ocpvirt_windows_compliance
    Run as Administrator
#>

$ErrorActionPreference = "Continue"

# Colors for output
function Write-Status {
    param(
        [string]$Test,
        [bool]$Passed,
        [string]$Details = ""
    )

    $status = if ($Passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($Passed) { "Green" } else { "Red" }

    Write-Host "$status " -ForegroundColor $color -NoNewline
    Write-Host "$Test" -NoNewline
    if ($Details) {
        Write-Host " - $Details" -ForegroundColor Gray
    } else {
        Write-Host ""
    }
}

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
}

# Track results
$results = @{
    Passed = 0
    Failed = 0
    Tests = @()
}

function Add-Result {
    param([string]$Test, [bool]$Passed, [string]$Details = "")
    Write-Status -Test $Test -Passed $Passed -Details $Details
    if ($Passed) { $script:results.Passed++ } else { $script:results.Failed++ }
    $script:results.Tests += @{ Test = $Test; Passed = $Passed; Details = $Details }
}

# ============================================================
# START VERIFICATION
# ============================================================

Write-Host ""
Write-Host "Windows VM Configuration Verification" -ForegroundColor Yellow
Write-Host "For: ansible_tmm.ocpvirt_windows_compliance" -ForegroundColor Yellow
Write-Host "Run Date: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# ------------------------------------------------------------
Write-Header "System Information"
# ------------------------------------------------------------

$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem

Write-Host "Computer Name: $($env:COMPUTERNAME)" -ForegroundColor White
Write-Host "OS: $($os.Caption)" -ForegroundColor White
Write-Host "Version: $($os.Version)" -ForegroundColor White
Write-Host "Architecture: $($os.OSArchitecture)" -ForegroundColor White
Write-Host "Memory: $([math]::Round($computer.TotalPhysicalMemory / 1GB, 2)) GB" -ForegroundColor White

# ------------------------------------------------------------
Write-Header "WinRM Service"
# ------------------------------------------------------------

# Check WinRM service status
$winrmService = Get-Service WinRM -ErrorAction SilentlyContinue
if ($winrmService) {
    Add-Result -Test "WinRM Service Exists" -Passed $true
    Add-Result -Test "WinRM Service Running" -Passed ($winrmService.Status -eq "Running") -Details $winrmService.Status
    Add-Result -Test "WinRM Startup Type Automatic" -Passed ($winrmService.StartType -eq "Automatic") -Details $winrmService.StartType
} else {
    Add-Result -Test "WinRM Service Exists" -Passed $false -Details "Service not found"
}

# ------------------------------------------------------------
Write-Header "WinRM Listeners"
# ------------------------------------------------------------

# Check HTTP listener (5985)
$httpListener = Get-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Transport='HTTP'; Address='*'} -ErrorAction SilentlyContinue
if ($httpListener) {
    Add-Result -Test "WinRM HTTP Listener (5985)" -Passed $true -Details "Port $($httpListener.Port)"
} else {
    Add-Result -Test "WinRM HTTP Listener (5985)" -Passed $false -Details "Not configured"
}

# Check HTTPS listener (5986)
$httpsListener = Get-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Transport='HTTPS'; Address='*'} -ErrorAction SilentlyContinue
if ($httpsListener) {
    Add-Result -Test "WinRM HTTPS Listener (5986)" -Passed $true -Details "Port $($httpsListener.Port)"

    # Check certificate
    $thumbprint = $httpsListener.CertificateThumbprint
    if ($thumbprint) {
        $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $thumbprint }
        if ($cert) {
            $daysUntilExpiry = ($cert.NotAfter - (Get-Date)).Days
            Add-Result -Test "HTTPS Certificate Valid" -Passed ($daysUntilExpiry -gt 0) -Details "Expires in $daysUntilExpiry days"
        }
    }
} else {
    Add-Result -Test "WinRM HTTPS Listener (5986)" -Passed $false -Details "Not configured"
}

# ------------------------------------------------------------
Write-Header "WinRM Authentication"
# ------------------------------------------------------------

$authConfig = Get-Item WSMan:\localhost\Service\Auth -ErrorAction SilentlyContinue

if ($authConfig) {
    $basicAuth = (Get-Item WSMan:\localhost\Service\Auth\Basic -ErrorAction SilentlyContinue).Value
    Add-Result -Test "Basic Authentication Enabled" -Passed ($basicAuth -eq "true") -Details $basicAuth

    $kerberosAuth = (Get-Item WSMan:\localhost\Service\Auth\Kerberos -ErrorAction SilentlyContinue).Value
    Write-Host "       Kerberos Auth: $kerberosAuth" -ForegroundColor Gray

    $negotiateAuth = (Get-Item WSMan:\localhost\Service\Auth\Negotiate -ErrorAction SilentlyContinue).Value
    Write-Host "       Negotiate Auth: $negotiateAuth" -ForegroundColor Gray
}

$allowUnencrypted = (Get-Item WSMan:\localhost\Service\AllowUnencrypted -ErrorAction SilentlyContinue).Value
Add-Result -Test "Allow Unencrypted (for HTTP)" -Passed ($allowUnencrypted -eq "true") -Details $allowUnencrypted

# ------------------------------------------------------------
Write-Header "WinRM Configuration"
# ------------------------------------------------------------

$maxMemory = (Get-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB -ErrorAction SilentlyContinue).Value
Add-Result -Test "Max Memory Per Shell >= 2048 MB" -Passed ([int]$maxMemory -ge 2048) -Details "$maxMemory MB"

$maxTimeout = (Get-Item WSMan:\localhost\MaxTimeoutms -ErrorAction SilentlyContinue).Value
Write-Host "       Max Timeout: $maxTimeout ms" -ForegroundColor Gray

# ------------------------------------------------------------
Write-Header "Firewall Rules"
# ------------------------------------------------------------

# Check WinRM HTTP rule
$winrmHttpRule = Get-NetFirewallRule -DisplayName "*WinRM*HTTP*" -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $true -and $_.Direction -eq "Inbound" }
if (-not $winrmHttpRule) {
    $winrmHttpRule = Get-NetFirewallRule | Where-Object { $_.DisplayName -match "WinRM" -and $_.DisplayName -match "HTTP" } -ErrorAction SilentlyContinue
}
Add-Result -Test "Firewall: WinRM HTTP (5985)" -Passed ($null -ne $winrmHttpRule) -Details $(if ($winrmHttpRule) { "Enabled" } else { "Not found" })

# Check WinRM HTTPS rule
$winrmHttpsRule = Get-NetFirewallRule -DisplayName "*WinRM*HTTPS*" -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $true -and $_.Direction -eq "Inbound" }
Add-Result -Test "Firewall: WinRM HTTPS (5986)" -Passed ($null -ne $winrmHttpsRule) -Details $(if ($winrmHttpsRule) { "Enabled" } else { "Not found" })

# Check RDP rule
$rdpRule = Get-NetFirewallRule -DisplayName "*Remote Desktop*" -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $true -and $_.Direction -eq "Inbound" } | Select-Object -First 1
Add-Result -Test "Firewall: Remote Desktop (3389)" -Passed ($null -ne $rdpRule) -Details $(if ($rdpRule) { "Enabled" } else { "Not found" })

# Check if ports are actually listening
$listeners = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue

$port5985 = $listeners | Where-Object { $_.LocalPort -eq 5985 }
Add-Result -Test "Port 5985 Listening" -Passed ($null -ne $port5985)

$port5986 = $listeners | Where-Object { $_.LocalPort -eq 5986 }
Add-Result -Test "Port 5986 Listening" -Passed ($null -ne $port5986)

$port3389 = $listeners | Where-Object { $_.LocalPort -eq 3389 }
Add-Result -Test "Port 3389 Listening" -Passed ($null -ne $port3389)

# ------------------------------------------------------------
Write-Header "Remote Desktop"
# ------------------------------------------------------------

$rdpEnabled = (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -ErrorAction SilentlyContinue).fDenyTSConnections
Add-Result -Test "Remote Desktop Enabled" -Passed ($rdpEnabled -eq 0) -Details $(if ($rdpEnabled -eq 0) { "Enabled" } else { "Disabled" })

# ------------------------------------------------------------
Write-Header "PowerShell Configuration"
# ------------------------------------------------------------

$executionPolicy = Get-ExecutionPolicy
Add-Result -Test "Execution Policy (RemoteSigned or less)" -Passed ($executionPolicy -in @("RemoteSigned", "Unrestricted", "Bypass")) -Details $executionPolicy

$psVersion = $PSVersionTable.PSVersion
Write-Host "       PowerShell Version: $psVersion" -ForegroundColor Gray

# ------------------------------------------------------------
Write-Header "VirtIO Guest Tools"
# ------------------------------------------------------------

# Check for QEMU Guest Agent service
$qemuService = Get-Service "QEMU-GA" -ErrorAction SilentlyContinue
if ($qemuService) {
    Add-Result -Test "QEMU Guest Agent Installed" -Passed $true -Details $qemuService.Status
} else {
    # Try alternate service name
    $qemuService = Get-Service "*qemu*" -ErrorAction SilentlyContinue | Select-Object -First 1
    Add-Result -Test "QEMU Guest Agent Installed" -Passed ($null -ne $qemuService) -Details $(if ($qemuService) { $qemuService.Status } else { "Not found" })
}

# Check for VirtIO drivers
$virtioDrivers = Get-WmiObject Win32_PnPSignedDriver | Where-Object { $_.DeviceName -like "*VirtIO*" -or $_.DeviceName -like "*Red Hat*" }
$virtioCount = ($virtioDrivers | Measure-Object).Count
Add-Result -Test "VirtIO Drivers Installed" -Passed ($virtioCount -gt 0) -Details "$virtioCount driver(s) found"

# ------------------------------------------------------------
Write-Header "Setup Completion Marker"
# ------------------------------------------------------------

$markerFile = "C:\setup-complete.txt"
if (Test-Path $markerFile) {
    $markerContent = Get-Content $markerFile -Raw
    Add-Result -Test "Setup Marker File Exists" -Passed $true -Details $markerFile
    Write-Host "       Content: $markerContent" -ForegroundColor Gray
} else {
    Add-Result -Test "Setup Marker File Exists" -Passed $false -Details "File not found"
}

# ------------------------------------------------------------
Write-Header "Network Configuration"
# ------------------------------------------------------------

$ipAddresses = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" }
foreach ($ip in $ipAddresses) {
    Write-Host "       IP: $($ip.IPAddress) / $($ip.PrefixLength) on $($ip.InterfaceAlias)" -ForegroundColor Gray
}

# ------------------------------------------------------------
Write-Header "Quick Connectivity Test"
# ------------------------------------------------------------

# Test WinRM locally
try {
    $testResult = Test-WSMan -ComputerName localhost -ErrorAction Stop
    Add-Result -Test "Test-WSMan localhost" -Passed $true -Details "Success"
} catch {
    Add-Result -Test "Test-WSMan localhost" -Passed $false -Details $_.Exception.Message
}

# ============================================================
# SUMMARY
# ============================================================

Write-Header "SUMMARY"

$totalTests = $results.Passed + $results.Failed
$passRate = if ($totalTests -gt 0) { [math]::Round(($results.Passed / $totalTests) * 100, 1) } else { 0 }

Write-Host ""
Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $($results.Passed)" -ForegroundColor Green
Write-Host "Failed: $($results.Failed)" -ForegroundColor $(if ($results.Failed -gt 0) { "Red" } else { "Green" })
Write-Host "Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 80) { "Green" } elseif ($passRate -ge 60) { "Yellow" } else { "Red" })
Write-Host ""

if ($results.Failed -eq 0) {
    Write-Host "All checks passed! The VM is ready for Ansible connectivity." -ForegroundColor Green
} else {
    Write-Host "Some checks failed. Review the output above and fix the issues." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Failed Tests:" -ForegroundColor Red
    $results.Tests | Where-Object { -not $_.Passed } | ForEach-Object {
        Write-Host "  - $($_.Test): $($_.Details)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan

# ============================================================
# ANSIBLE CONNECTION TEST COMMAND
# ============================================================

Write-Host ""
Write-Host "To test from your Ansible control node, run:" -ForegroundColor Yellow
Write-Host ""

$primaryIP = ($ipAddresses | Select-Object -First 1).IPAddress
Write-Host @"
# Test HTTP (5985)
ansible -i "$primaryIP," all -m ansible.windows.win_ping \
  -e "ansible_user=Administrator" \
  -e "ansible_password=YOUR_PASSWORD_HERE" \
  -e "ansible_connection=winrm" \
  -e "ansible_winrm_transport=basic" \
  -e "ansible_port=5985"

# Test HTTPS (5986)
ansible -i "$primaryIP," all -m ansible.windows.win_ping \
  -e "ansible_user=Administrator" \
  -e "ansible_password=YOUR_PASSWORD_HERE" \
  -e "ansible_connection=winrm" \
  -e "ansible_winrm_transport=basic" \
  -e "ansible_winrm_server_cert_validation=ignore" \
  -e "ansible_port=5986"
"@ -ForegroundColor Cyan

Write-Host ""
