# Create a Windows VM Template for Compliance Automation

This guide walks you through creating a Windows Server 2019 or 2022 VM template in OpenShift Virtualization that is pre-configured for use with the `ansible_tmm.ocpvirt_windows_compliance` Ansible collection.

## What This Template Provides

- **UEFI boot mode** with Secure Boot support (STIG requirement)
- **WinRM enabled** over HTTPS for Ansible connectivity
- **GPT disk partitioning** (required for UEFI)
- **Administrator account** configured and ready
- **Firewall rules** for WinRM ports 5985/5986
- **PowerShell remoting** enabled

After creating this template, you can use your compliance collection to:
1. Install DISA SCC
2. Run compliance scans
3. Apply STIG remediation
4. Generate compliance reports

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| OpenShift Container Platform | 4.12+ with Virtualization operator installed |
| Namespace | A project/namespace where you have VM creation permissions |
| Windows ISO | Windows Server 2019 or 2022 ISO accessible via URL |
| Storage Class | A storage class that supports ReadWriteMany (RWX) for cloning |

---

## Step 1: Navigate to the VM Catalog

1. Log into the OpenShift Console
2. Switch to the **Administrator** perspective (or Developer if you prefer)
3. Navigate to **Virtualization** → **Catalog**
4. Click the **Template catalog** tab

---

## Step 2: Select the Windows Template

1. In the search bar, type `windows server 2022` (or `2019` for older version)
2. Click on the **Microsoft Windows Server 2022 VM** tile
3. A dialog will appear showing the default template configuration

> **Note:** There is no boot source configured by default. We will customize this.

---

## Step 3: Configure the Boot Sources

In the template dialog, configure the following:

| Setting | Value |
|---------|-------|
| **Name** | `win2022-compliance-template` |
| **Boot from CD** | ✅ Enabled |
| **CD source** | `URL (creates PVC)` |
| **Image URL** | Your Windows Server ISO URL (e.g., `https://your-server/windows2022.iso`) |
| **CD disk size** | `6 GiB` |
| **Disk source** | `Blank` |
| **Disk size** | `60 GiB` (or larger for production) |
| **Mount Windows drivers disk** | ✅ Enabled (required for VirtIO) |

Click **Customize VirtualMachine** to continue.

---

## Step 4: Configure UEFI Boot Mode

1. On the **Customize and create VirtualMachine** screen, find the **Boot mode** option
2. Click the **edit pencil** icon next to Boot mode
3. In the popup, select **UEFI** from the dropdown
4. ✅ Enable **Secure Boot** (recommended for STIG compliance)
5. Click **Save**

> **Important:** The autounattend.xml in Step 5 is configured for UEFI with GPT partitioning. Do not use BIOS mode.

---

## Step 5: Configure Sysprep (autounattend.xml)

1. Click the **Scripts** tab
2. Scroll down to the **Sysprep** section
3. Click **Edit**
4. In the **autounattend.xml** field, paste the complete XML from the section below
5. Click **Save**

### Complete autounattend.xml for Compliance Automation

Copy and paste this entire XML block:

```xml
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:schemas-microsoft-com:unattend">

  <!-- ============================================================
       WINDOWS PE PASS - Disk Configuration and OS Installation
       ============================================================ -->
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">

      <!-- GPT Disk Configuration for UEFI Boot -->
      <DiskConfiguration>
        <Disk wcm:action="add">
          <DiskID>0</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
          <CreatePartitions>
            <!-- EFI System Partition (ESP) - Required for UEFI -->
            <CreatePartition wcm:action="add">
              <Order>1</Order>
              <Size>100</Size>
              <Type>EFI</Type>
            </CreatePartition>
            <!-- Microsoft Reserved Partition (MSR) -->
            <CreatePartition wcm:action="add">
              <Order>2</Order>
              <Size>16</Size>
              <Type>MSR</Type>
            </CreatePartition>
            <!-- Windows OS Partition - Uses remaining space -->
            <CreatePartition wcm:action="add">
              <Order>3</Order>
              <Extend>true</Extend>
              <Type>Primary</Type>
            </CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <!-- Format EFI Partition -->
            <ModifyPartition wcm:action="add">
              <Order>1</Order>
              <PartitionID>1</PartitionID>
              <Format>FAT32</Format>
              <Label>System</Label>
            </ModifyPartition>
            <!-- Format Windows Partition -->
            <ModifyPartition wcm:action="add">
              <Order>2</Order>
              <PartitionID>3</PartitionID>
              <Format>NTFS</Format>
              <Label>Windows</Label>
              <Letter>C</Letter>
            </ModifyPartition>
          </ModifyPartitions>
        </Disk>
      </DiskConfiguration>

      <!-- Windows Edition Selection -->
      <ImageInstall>
        <OSImage>
          <InstallFrom>
            <MetaData wcm:action="add">
              <Key>/IMAGE/NAME</Key>
              <!-- Change to "Windows Server 2019 SERVERSTANDARD" for 2019 -->
              <Value>Windows Server 2022 SERVERSTANDARD</Value>
            </MetaData>
          </InstallFrom>
          <InstallTo>
            <DiskID>0</DiskID>
            <PartitionID>3</PartitionID>
          </InstallTo>
        </OSImage>
      </ImageInstall>

      <!-- User Data -->
      <UserData>
        <AcceptEula>true</AcceptEula>
        <FullName>Administrator</FullName>
        <Organization>Compliance Team</Organization>
      </UserData>

    </component>

    <!-- Locale Settings for PE -->
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage>
        <UILanguage>en-US</UILanguage>
      </SetupUILanguage>
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
  </settings>

  <!-- ============================================================
       SPECIALIZE PASS - Machine-Specific Configuration
       ============================================================ -->
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">

      <!-- Computer Name - Will be changed after cloning -->
      <ComputerName>WIN-TEMPLATE</ComputerName>

      <!-- Timezone - Adjust as needed -->
      <TimeZone>UTC</TimeZone>

      <!-- Initial Auto-Logon for Setup -->
      <AutoLogon>
        <Enabled>true</Enabled>
        <LogonCount>5</LogonCount>
        <Username>Administrator</Username>
        <Password>
          <!-- CHANGE THIS PASSWORD for production use -->
          <Value>CHANGE_ME_BEFORE_USE</Value>
          <PlainText>true</PlainText>
        </Password>
      </AutoLogon>

    </component>

    <!-- Disable IE Enhanced Security for initial setup -->
    <component name="Microsoft-Windows-IE-ESC" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <IEHardenAdmin>false</IEHardenAdmin>
      <IEHardenUser>false</IEHardenUser>
    </component>

    <!-- Server Manager - Don't show at logon -->
    <component name="Microsoft-Windows-ServerManager-SvrMgrNc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <DoNotOpenServerManagerAtLogon>true</DoNotOpenServerManagerAtLogon>
    </component>

  </settings>

  <!-- ============================================================
       OOBE SYSTEM PASS - First Boot Configuration
       ============================================================ -->
  <settings pass="oobeSystem">

    <!-- Locale Settings -->
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>

    <!-- Shell Setup and First Logon Commands -->
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">

      <!-- Skip all OOBE screens -->
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideLocalAccountScreen>true</HideLocalAccountScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>3</ProtectYourPC>
        <SkipMachineOOBE>true</SkipMachineOOBE>
        <SkipUserOOBE>true</SkipUserOOBE>
      </OOBE>

      <!-- Administrator Account Setup -->
      <UserAccounts>
        <AdministratorPassword>
          <!-- CHANGE THIS PASSWORD for production use -->
          <Value>CHANGE_ME_BEFORE_USE</Value>
          <PlainText>true</PlainText>
        </AdministratorPassword>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Name>Administrator</Name>
            <DisplayName>Administrator</DisplayName>
            <Group>Administrators</Group>
            <Description>Built-in Administrator Account</Description>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>

      <!-- Auto-Logon for First Boot Commands -->
      <AutoLogon>
        <Enabled>true</Enabled>
        <LogonCount>5</LogonCount>
        <Username>Administrator</Username>
        <Password>
          <Value>CHANGE_ME_BEFORE_USE</Value>
          <PlainText>true</PlainText>
        </Password>
      </AutoLogon>

      <!-- ============================================================
           FIRST LOGON COMMANDS - WinRM and Ansible Setup
           These run automatically on first boot
           ============================================================ -->
      <FirstLogonCommands>

        <!-- 1. Set Execution Policy for PowerShell -->
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <CommandLine>powershell.exe -Command "Set-ExecutionPolicy RemoteSigned -Force"</CommandLine>
          <Description>Set PowerShell Execution Policy</Description>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>

        <!-- 2. Enable WinRM Service -->
        <SynchronousCommand wcm:action="add">
          <Order>2</Order>
          <CommandLine>powershell.exe -Command "Enable-PSRemoting -Force -SkipNetworkProfileCheck"</CommandLine>
          <Description>Enable PowerShell Remoting</Description>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>

        <!-- 3. Configure WinRM Service -->
        <SynchronousCommand wcm:action="add">
          <Order>3</Order>
          <CommandLine>powershell.exe -Command "Set-Service WinRM -StartupType Automatic"</CommandLine>
          <Description>Set WinRM to Auto Start</Description>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>

        <!-- 4. Configure WinRM for Ansible - Basic Auth -->
        <SynchronousCommand wcm:action="add">
          <Order>4</Order>
          <CommandLine>powershell.exe -Command "Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true"</CommandLine>
          <Description>Enable Basic Authentication</Description>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>

        <!-- 5. Configure WinRM for Ansible - Allow Unencrypted (set to false for production with HTTPS) -->
        <SynchronousCommand wcm:action="add">
          <Order>5</Order>
          <CommandLine>powershell.exe -Command "Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true"</CommandLine>
          <Description>Allow Unencrypted Traffic (for initial setup)</Description>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>

        <!-- 6. Configure WinRM Listener for HTTP (5985) -->
        <SynchronousCommand wcm:action="add">
          <Order>6</Order>
          <CommandLine>powershell.exe -Command "if (!(Get-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Transport='HTTP'; Address='*'} -ErrorAction SilentlyContinue)) { New-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Transport='HTTP'; Address='*'} }"</CommandLine>
          <Description>Create HTTP Listener</Description>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>

        <!-- 7. Create Self-Signed Certificate for HTTPS -->
        <SynchronousCommand wcm:action="add">
          <Order>7</Order>
          <CommandLine>powershell.exe -Command "$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME, localhost -CertStoreLocation Cert:\LocalMachine\My -NotAfter (Get-Date).AddYears(5); New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbprint $cert.Thumbprint -Force"</CommandLine>
          <Description>Create HTTPS Listener with Self-Signed Cert</Description>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>

        <!-- 8. Configure WinRM Memory and Timeouts -->
        <SynchronousCommand wcm:action="add">
          <Order>8</Order>
          <CommandLine>powershell.exe -Command "Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 2048"</CommandLine>
          <Description>Increase WinRM Memory Limit</Description>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>

        <!-- 9. Open Firewall for WinRM HTTP (5985) -->
        <SynchronousCommand wcm:action="add">
          <Order>9</Order>
          <CommandLine>netsh advfirewall firewall add rule name="WinRM HTTP" dir=in action=allow protocol=TCP localport=5985</CommandLine>
          <Description>Open Firewall Port 5985</Description>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>

        <!-- 10. Open Firewall for WinRM HTTPS (5986) -->
        <SynchronousCommand wcm:action="add">
          <Order>10</Order>
          <CommandLine>netsh advfirewall firewall add rule name="WinRM HTTPS" dir=in action=allow protocol=TCP localport=5986</CommandLine>
          <Description>Open Firewall Port 5986</Description>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>

        <!-- 11. Restart WinRM to Apply Changes -->
        <SynchronousCommand wcm:action="add">
          <Order>11</Order>
          <CommandLine>powershell.exe -Command "Restart-Service WinRM"</CommandLine>
          <Description>Restart WinRM Service</Description>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>

        <!-- 12. Enable Remote Desktop (optional, useful for troubleshooting) -->
        <SynchronousCommand wcm:action="add">
          <Order>12</Order>
          <CommandLine>powershell.exe -Command "Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0"</CommandLine>
          <Description>Enable Remote Desktop</Description>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>

        <!-- 13. Open Firewall for RDP -->
        <SynchronousCommand wcm:action="add">
          <Order>13</Order>
          <CommandLine>netsh advfirewall firewall add rule name="Remote Desktop" dir=in action=allow protocol=TCP localport=3389</CommandLine>
          <Description>Open Firewall Port 3389 for RDP</Description>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>

        <!-- 14. Install VirtIO Guest Agent (if available) -->
        <SynchronousCommand wcm:action="add">
          <Order>14</Order>
          <CommandLine>powershell.exe -Command "if (Test-Path 'E:\virtio-win-guest-tools.exe') { Start-Process -FilePath 'E:\virtio-win-guest-tools.exe' -ArgumentList '/install /passive /norestart' -Wait }"</CommandLine>
          <Description>Install VirtIO Guest Tools</Description>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>

        <!-- 15. Create marker file indicating setup is complete -->
        <SynchronousCommand wcm:action="add">
          <Order>15</Order>
          <CommandLine>powershell.exe -Command "New-Item -Path 'C:\setup-complete.txt' -ItemType File -Value 'WinRM and Ansible setup completed at: ' + (Get-Date)"</CommandLine>
          <Description>Create Setup Complete Marker</Description>
          <RequiresUserInput>false</RequiresUserInput>
        </SynchronousCommand>

      </FirstLogonCommands>

    </component>
  </settings>

</unattend>
```

---

## Step 6: Create the Virtual Machine

1. Review your configuration:
   - **Name:** `win2022-compliance-template`
   - **Boot mode:** UEFI (with Secure Boot enabled)
   - **Sysprep:** autounattend.xml configured

2. Click **Create VirtualMachine**

3. The VM will begin provisioning:
   - Download the ISO image (may take several minutes)
   - Boot from the ISO
   - Execute the unattended installation
   - Run the FirstLogonCommands to configure WinRM

---

## Step 7: Monitor the Installation

1. Navigate to **Virtualization** → **VirtualMachines**
2. Click on your `win2022-compliance-template` VM
3. Go to the **Console** tab to watch the installation progress

The installation typically takes **15-25 minutes** and will:
- Partition the disk (GPT layout)
- Install Windows Server
- Configure the Administrator account
- Run all FirstLogonCommands (WinRM setup)
- Auto-login to desktop

**How to know it's complete:**
- You'll see the Windows desktop
- File `C:\setup-complete.txt` exists
- WinRM service is running

---

## Step 8: Verify WinRM Connectivity

Before cloning the template, verify that WinRM is working.

### From the VM Console:

```powershell
# Check WinRM service status
Get-Service WinRM

# Verify listeners are configured
winrm enumerate winrm/config/Listener

# Check firewall rules
Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*WinRM*" }

# View the setup completion marker
Get-Content C:\setup-complete.txt
```

### From your Ansible control node (or any Linux host with network access):

```bash
# Test HTTP (5985)
curl -v http://<vm-ip>:5985/wsman

# Test with Python/winrm
python3 -c "
import winrm
s = winrm.Session('http://<vm-ip>:5985/wsman',
    auth=('Administrator', 'CHANGE_ME_BEFORE_USE'),
    transport='basic')
r = s.run_cmd('hostname')
print(r.std_out.decode())
"
```

---

## Step 9: Stop the VM and Clone the Disk

Once WinRM is verified and working:

1. **Stop the VM:**
   - On the VM details page, click the **Stop** button (square icon)
   - Wait for status to show **Stopped**

2. **Navigate to Storage:**
   - Go to **Storage** → **PersistentVolumeClaims**
   - Find the PVC named `win2022-compliance-template` (the 60 GiB disk, not the ISO)

3. **Clone the PVC:**
   - Click the **⋮** (three dots) menu on the right
   - Select **Clone PVC**

4. **Configure the Clone:**
   | Setting | Value |
   |---------|-------|
   | **Name** | `win2022-stig-template` |
   | **Access mode** | `Shared access (RWX)` |
   | **StorageClass** | Your RWX-capable storage class (e.g., `ocs-storagecluster-ceph-rbd`) |

5. Click **Clone**

---

## Step 10: Use the Template for New VMs

Now you can quickly create new Windows VMs from your template:

1. Go to **Virtualization** → **Catalog** → **Template catalog**
2. Select **Microsoft Windows Server 2022 VM**
3. Configure:
   | Setting | Value |
   |---------|-------|
   | **Name** | Your new VM name (e.g., `win-prod-01`) |
   | **Boot from CD** | ❌ Disabled |
   | **Disk source** | `PVC (clone PVC)` |
   | **PVC name** | `win2022-stig-template` |
   | **PVC namespace** | The namespace where you created the template |

4. Click **Customize VirtualMachine**
5. Set **Boot mode** to **UEFI** (with Secure Boot if needed)
6. Click **Create VirtualMachine**

The new VM will boot in **seconds** instead of going through the full installation.

---

## Step 11: Run Compliance Automation

With your new VM running, you can now use the Ansible collection:

```bash
# Add the VM to your inventory
cat >> inventory/hosts.yml << EOF
windows:
  hosts:
    win-prod-01:
      ansible_host: <vm-ip-address>
      ansible_user: Administrator
      ansible_password: "CHANGE_ME_BEFORE_USE"
      ansible_connection: winrm
      ansible_winrm_transport: basic
      ansible_winrm_server_cert_validation: ignore
      ansible_port: 5985
EOF

# Test connectivity
ansible win-prod-01 -i inventory/hosts.yml -m ansible.windows.win_ping

# Install SCC
ansible-playbook ansible_tmm.ocpvirt_windows_compliance.install_scc \
  -i inventory/hosts.yml \
  -e "tenant_namespace=production" \
  --limit win-prod-01

# Run compliance scan
ansible-playbook ansible_tmm.ocpvirt_windows_compliance.scan \
  -i inventory/hosts.yml \
  -e "tenant_namespace=production" \
  --limit win-prod-01

# Apply STIG remediation
ansible-playbook ansible_tmm.ocpvirt_windows_compliance.remediate \
  -i inventory/hosts.yml \
  -e "tenant_namespace=production" \
  --limit win-prod-01
```

---

## Appendix A: Windows Server 2019 Changes

If using Windows Server 2019 instead of 2022, change this line in the autounattend.xml:

```xml
<!-- In the ImageInstall section -->
<Value>Windows Server 2019 SERVERSTANDARD</Value>
```

For Datacenter edition:
```xml
<Value>Windows Server 2022 SERVERDATACENTER</Value>
<!-- or -->
<Value>Windows Server 2019 SERVERDATACENTER</Value>
```

---

## Appendix B: Security Hardening for Production

Before using in production, consider these security improvements:

### 1. Change the Default Password

The autounattend.xml contains `CHANGE_ME_BEFORE_USE` as a placeholder. For production:
- Use a strong, unique password
- Or use Ansible to change the password after provisioning

### 2. Disable Basic Auth (use NTLM/Kerberos)

After initial setup, secure WinRM by disabling Basic auth:

```powershell
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $false
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $false
```

Update your Ansible inventory to use NTLM:
```yaml
ansible_winrm_transport: ntlm
ansible_port: 5986  # Use HTTPS
```

### 3. Use Certificate-Based Authentication

For highest security, configure WinRM with certificate authentication and use a proper CA-signed certificate instead of self-signed.

---

## Appendix C: Troubleshooting

| Issue | Solution |
|-------|----------|
| VM won't boot from ISO | Verify ISO URL is accessible and correct |
| Disk not found during install | Ensure VirtIO drivers disk is mounted |
| WinRM connection refused | Check firewall rules, verify service is running |
| HTTPS certificate errors | Use `ansible_winrm_server_cert_validation: ignore` for self-signed |
| Installation hangs at "Getting ready" | Increase VM memory to at least 4 GiB |
| Clone fails | Ensure storage class supports RWX and cloning |

### Useful Commands

```powershell
# Check WinRM configuration
winrm get winrm/config

# List WinRM listeners
winrm enumerate winrm/config/Listener

# Test WinRM locally
Test-WSMan -ComputerName localhost

# Check certificate
Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*$env:COMPUTERNAME*" }
```

---

## Summary

You now have:

1. ✅ A Windows Server template with UEFI/Secure Boot
2. ✅ WinRM configured for Ansible connectivity
3. ✅ A cloned PVC ready for rapid VM provisioning
4. ✅ VMs ready for compliance scanning and remediation

**Next Steps:**
- Run the `install_scc` playbook to install DISA SCC
- Run the `scan` playbook to perform compliance assessment
- Run the `remediate` playbook to apply STIG controls
- Run the `report` playbook to generate compliance reports
