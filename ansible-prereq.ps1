Param(

    [parameter(Mandatory = $false)] $InterfaceName="Ethernet0"
)

$Global:InterfaceName=$InterfaceName
function SetGlobals()
{
    if ((Get-NetAdapter -InterfaceAlias "vEthernet ($Global:InterfaceName)" -ErrorAction SilentlyContinue))
    {
        $Global:ManagementIp = Get-InterfaceIpAddress -InterfaceName "vEthernet ($Global:InterfaceName)"
        $Global:ManagementSubnet = Get-MgmtSubnet -InterfaceName "vEthernet ($Global:InterfaceName)"
    }
    elseif ((Get-NetAdapter -InterfaceAlias "$Global:InterfaceName" -ErrorAction SilentlyContinue))
    {
        $Global:ManagementIp = Get-InterfaceIpAddress -InterfaceName "$Global:InterfaceName"
        $Global:ManagementSubnet = Get-MgmtSubnet -InterfaceName "$Global:InterfaceName"
    }
    else {
        throw "$Global:InterfaceName doesn't exist"
    }
}
function InstallOPENSSH()
{
    Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Start-Service sshd
    Set-Service -Name sshd -StartupType 'Automatic'

    if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled))
    {
        Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    }
    else
    {
      Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
    }

}
function VerifyPowerShell(){
    Get-Host | Select-Object Version
    Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name version -EA 0 | Where { $_.PSChildName -Match '^(?!S)\p{L}'} | Select PSChildName, version
}
function InstallWINRM (){
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = "https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"
    $file = "$env:temp\ConfigureRemotingForAnsible.ps1" 
    (New-Object -TypeName System.Net.WebClient).DownloadFile($url, $file)
    powershell.exe -ExecutionPolicy ByPass -File $file
    winrm get winrm/config/Service

    cmd /c 'winrm set winrm/config/service/auth @{Basic="true"}'
    cmd /c 'winrm set winrm/config/service @{AllowUnencrypted="true"}'

    netsh advfirewall firewall add rule name="ICMP Allow incoming V6 echo request" protocol="icmpv6:8,any" dir=in action=allow
    netsh advfirewall firewall add rule name="ICMP Allow incoming V4 echo request" protocol="icmpv4:8,any" dir=in action=allow

    Restart-Computer
}

SetGlobals
InstallOPENSSH
VerifyPowerShell
InstallWINRM
