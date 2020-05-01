#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs Puppet on a Windows machine
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
[CmdletBinding()]
param (
    # The FQDN of the Puppet master you are connecting to
    [Parameter(Mandatory = $false)]
    [string]
    $PuppetMaster = "puppettest-master.local",

    # The domain name you are using (might be irrelevant?)
    [Parameter(Mandatory = $false)]
    [string]
    $DomainName = "local",

    # The major version of Puppet to install
    [Parameter(Mandatory = $false)]
    [string]
    $PuppetVersion = "puppet6",

    # The specific puppet agent version to install
    [Parameter(Mandatory = $false)]
    [string]
    $PuppetAgentVersion = 'latest',

    # The port to connect to on the master
    [Parameter(Mandatory = $false)]
    [int]
    $MasterPort = 8140,

    # The Puppet envrionment (aka Git branch) to use
    [Parameter(Mandatory = $false)]
    [string]
    $PuppetEnvrionment = "puppet6_test",

    # Any extended CSR attributes you'd like to set (pp_service,pp_role,pp_envrironment)
    [Parameter(Mandatory = $false)]
    [hashtable]
    $CertificateExtensions,

    # Puppet agent service startup mode
    [Parameter(Mandatory = $false)]
    [ValidateSet('Automatic', 'Manual', 'Disabled')]
    [string]
    $StartupMode
)
## Setting up ##
function Get-CSRAttributes 
{
    $pp_env = Read-Host "pp_environment"
    $pp_service = Read-Host "pp_service"
    $pp_role = Read-Host "pp_role"

    $hash = @{
        pp_service     = $pp_service
        pp_role        = $pp_role
        pp_environment = $pp_env
    }
    while (!$correct) 
    {
        Write-Host "pp_environment: $pp_env`npp_service: $pp_service`npp_role: $pp_role"
        $correct = Read-Host "Is this correct? [y/n]"
        switch ($correct)
        {
            'y' { Return $hash }
            'n' 
            { 
                $pp_env = Read-Host "pp_environment"
                $pp_service = Read-Host "pp_service"
                $pp_role = Read-Host "pp_role"
                $hash = @{
                    pp_service     = $pp_service
                    pp_role        = $pp_role
                    pp_environment = $pp_env
                }
                Clear-Variable correct
            }
            default { Clear-Variable correct }
        }
    }
}
function Set-CSRAttributes
{
    param 
    (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $CSRAttributes
    )
    $csr_yaml_path = "$env:ProgramData\PuppetLabs\puppet\etc\csr_attributes.yaml"
    $csr_yaml_parent = Split-Path $csr_yaml_path
    if (!(Test-Path $csr_yaml_parent))
    {
        try
        {
            New-Item $csr_yaml_parent-ItemType Directory -ErrorAction Stop
        }
        catch
        {
            throw "Failed to create Puppet data directory."
        }
    }
    $csr_yaml = @('extension_requests:')
    foreach ($attribute in $CSRAttributes.GetEnumerator())
    {
        $csr_yaml += "  $($_.Name): $($_.Value)"
    }
    try
    {
        Set-Content $csr_yaml_path -Value $csr_yaml -ErrorAction Stop
    }
    catch
    {
        throw "failed to set yaml."
    }
}
## End Setup ##
## Checks ##
if (Get-Command puppet)
{
    throw "Puppet is already installed"
}
if ($PuppetVersion -match "^[1-9]$")
{
    $PuppetVersion = "puppet$($PuppetVersion)"
}
if ($PuppetMaster -notmatch ".$Domainname")
{
    $PuppetMaster = "$PuppetMaster.$domainname"
}
# Quick test to make sure we can get to the PuppetMaster
try
{
    Test-NetConnection $PuppetMaster -ErrorAction Stop | Out-Null
}
catch
{
    throw "Failed to contact $PuppetMaster, please check the name and network connection."
}

if (!$CertificateExtensions)
{
    while (!$answer)
    {
        $answer = Read-Host "Do you want to set extended CSR attributes? [y/n]"
        switch ($answer.ToLower()) 
        {
            'y' 
            {
                $CertificateExtensions = Get-CSRAttributes
            }
            'n' 
            {   
                # Do nothing
            }
            default { Clear-Variable answer } # Unrecognised input, try again
        }
    }
}
## End Checks ##
# For now we're getting the Puppet agent manually but ultimately I'd like to test getting it via chocolatey - that way we can keep the package up to date.
$arch = "x86"
if ( [Environment]::Is64BitOperatingSystem )
{
    $arch = "x64"
}
$DownloadURL = "https://downloads.puppetlabs.com/windows/$($PUPPETVERSION.ToLower())/puppet-agent-$arch-latest.msi"
if ($PuppetAgentVersion -ne 'latest')
{
    $DownloadURL = "https://downloads.puppetlabs.com/windows/$($PUPPETVERSION.ToLower())/puppet-agent-$PuppetAgentVersion-$arch.msi"
}

$tempname = ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count 8 | ForEach-Object { [char]$_ }))
$tempdir = "$env:TEMP\$tempname"
try
{
    New-Item $tempdir -ItemType Directory -ErrorAction Stop
}
catch
{
    throw "Failed to create temp directory"
}
$installer = "$tempdir\puppet.msi"
try
{
    Invoke-WebRequest -Uri $DownloadURL -OutFile $installer -ErrorAction Stop
}
catch
{
    Remove-Item $tempdir -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    "Failed to get Puppet installer.`n$($_.Exception.Message)"
}
$installer_params = @(
    '/qn',
    '/norestart',
    '/i',
    "$installer",
    "PUPPET_AGENT_STARTUP_MODE=$PuppetAgentStartupMode",
    "PUPPET_MASTER_SERVER=$PuppetServer",
    "PUPPET_AGENT_ENVIRONMENT=$PuppetEnvironment"
)
# do something for custom certnames here for those cases where we don't domain join a machine

try
{
    Start-Process msiexec.exe -ArgumentList $installer_params -Wait -NoNewWindow -ErrorAction Stop
}
catch
{
    Remove-Item $tempdir -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    throw "Failed to install Puppet agent.`n$($_.Exception.Message)"
}


if ($MasterPort -ne 8140)
{
    puppet.bat config set masterport $MasterPort --section main
}