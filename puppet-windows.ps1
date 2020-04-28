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

    # The version of Puppet to install
    [Parameter(Mandatory = $false)]
    [string]
    $PuppetVersion = "puppet6",

    # The port to connect to on the master
    [Parameter(Mandatory = $false)]
    [string]
    $MasterPort = "8140",

    # The Puppet envrionment (aka Git branch) to use
    [Parameter(Mandatory = $false)]
    [string]
    $PuppetEnvrionment = "puppet6_test",

    # Any extended CSR attributes you'd like to set (pp_service,pp_role,pp_envrironment)
    [Parameter(Mandatory = $false)]
    [hashtable]
    $ExtendedCAttributes
)
if (Get-Command puppet)
{
    throw "Puppet is already installed"
}
if ($PuppetVersion -match "^[1-9]$")
{
    $PuppetVersion = "puppet$($PuppetVersion)"
}

if ( [Environment]::Is64BitOperatingSystem )
{
    $DownloadURL = "https://downloads.puppetlabs.com/windows/$($PUPPETVERSION.ToLower())/puppet-agent-x64-latest.msi"
}
else
{
    $DownloadURL = "https://downloads.puppetlabs.com/windows/$($PUPPETVERSION.ToLower())/puppet-agent-x86-latest.msi"
}

$tempname = ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count 8 | ForEach-Object { [char]$_ }))
$tempdir = "$env:TEMP\$tempname"
try {
    New-Item $tempdir -ItemType Directory -ErrorAction Stop
}
catch {
    
}
$installer = "$tempdir\puppet.msi"
try {
    Invoke-WebRequest -Uri $DownloadURL -OutFile $installer -ErrorAction Stop
}
catch {
    
}
if (!$ExtendedCAttributes)
{
    $answer = Read-Host "Do you want to set extended CSR attributes? [y/n]"

}