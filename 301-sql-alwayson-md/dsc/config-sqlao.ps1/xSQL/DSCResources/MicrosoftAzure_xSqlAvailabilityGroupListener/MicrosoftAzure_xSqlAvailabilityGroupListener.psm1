#
# xSqlAvailabilityGroupListener: DSC resource that configures a SQL AlwaysOn Availability Group Listener.
#

function Get-TargetResource
{
    param
    (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $Name,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $AvailabilityGroupName,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $DomainNameFqdn,

        [String[]] $ListenerIPAddresses,

        [UInt32] $ListenerPortNumber = 1433,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $InstanceName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential] $DomainCredential,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential] $SqlAdministratorCredential
    )

    $bConfigured = Test-TargetResource -Name $Name -AvailabilityGroupName $AvailabilityGroupName -DomainNameFqdn $DomainNameFqdn -ListenerPortNumber $ListenerPortNumber -InstanceName  $InstanceName -DomainCredential $DomainCredential -SqlAdministratorCredential $SqlAdministratorCredential

    $returnValue = @{
        Name = $Name
        AvailabilityGroupName = $AvailabilityGroupName
        DomainNameFqdn = $DomainNameFqdn
        ListenerPortNumber = $ListenerPortNumber
        InstanceName = $InstanceName
        DomainCredential = $DomainCredential.UserName
        SqlAdministratorCredential = $SqlAdministratorCredential.UserName
        Configured = $bConfigured
    }

    $returnValue
}

function Set-TargetResource
{
    param
    (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $Name,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $AvailabilityGroupName,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $DomainNameFqdn,

        [String[]] $ListenerIPAddresses,

        [UInt32] $ListenerPortNumber = 1433,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $InstanceName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential] $DomainCredential,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential] $SqlAdministratorCredential
    )

    try {
        ($oldToken, $context, $newToken) = ImpersonateAs -cred $DomainCredential 

        Write-Verbose -Message "Configuring  the Availability Group Listener port to '$($ListenerPortNumber)' ..."

        $instance = Get-SqlInstanceName -Node  $env:COMPUTERNAME -InstanceName $InstanceName
        $s = Get-SqlServer -InstanceName $instance -Credential $SqlAdministratorCredential
        $ag = Get-SqlAvailabilityGroup -Name $AvailabilityGroupName -Server $s
        $subnetMask=(Get-ClusterNetwork)[0].AddressMask
        $ag | New-SqlAvailabilityGroupListener -Name $Name -StaticIp "$($ListenerIPAddresses[0])/$subnetMask" -Port $ListenerPortNumber
        $clusterResourceDependencyExpr = "([$($AvailabilityGroupName)_$($ListenerIPAddresses[0])])"

        for ($count=1; $count -le $ListenerIPAddresses.Length - 1; $count++) {
            $newIpv4AddrResName = "$($AvailabilityGroupName)_$($ListenerIPAddresses[$count])"
            Add-ClusterResource -Name $newIpv4AddrResName -Group $AvailabilityGroupName -ResourceType "IP Address" 
            $newIpv4AddrRes = Get-ClusterResource -Name $newIpv4AddrResName
            $newIpv4AddrRes |
            Set-ClusterParameter -Multiple @{
                                    "Address" = $ListenerIPAddresses[$count]
                                    "SubnetMask" = $subnetMask
                                    "EnableDhcp" = 0
                                }
            $newIpv4AddrRes | Start-ClusterResource       
            $clusterResourceDependencyExpr += " and ([$newIpv4AddrResName])"
        }
        
        Set-ClusterResourceDependency -Resource "$($AvailabilityGroupName)_$Name" -Dependency $clusterResourceDependencyExpr
    }
    finally
    {
        if ($context)
        {
            $context.Undo()
            $context.Dispose()
            CloseUserToken($newToken)
        }
    }      
}

function Test-TargetResource
{
    param
    (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $Name,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $AvailabilityGroupName,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $DomainNameFqdn,

        [String[]] $ListenerIPAddresses,

        [UInt32] $ListenerPortNumber = 1433,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $InstanceName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential] $DomainCredential,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential] $SqlAdministratorCredential
    )

    Write-Verbose -Message "Checking if SQL AG Listener '$($Name)' exists on instance '$($InstanceName)' ..."

    $instance = Get-SqlInstanceName -Node  $env:COMPUTERNAME -InstanceName $InstanceName
    $s = Get-SqlServer -InstanceName $instance -Credential $SqlAdministratorCredential

    $ag = $s.AvailabilityGroups
    $agl = $ag.AvailabilityGroupListeners
    $bRet = $true

    if ($agl)
    {
        Write-Verbose -Message "SQL AG Listener '$($Name)' found."
    }
    else
    {
        Write-Verbose "SQL AG Listener '$($Name)' NOT found."
        $bRet = $false
    }

    return $bRet
}


function Get-SqlServer([string]$InstanceName, [PSCredential]$Credential)
{
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
    $sc = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
    $sc.ServerInstance = $InstanceName
    $sc.ConnectAsUser = $true
    if ($Credential.GetNetworkCredential().Domain -and $Credential.GetNetworkCredential().Domain -ne $env:COMPUTERNAME)
    {
        $sc.ConnectAsUserName = "$($Credential.GetNetworkCredential().UserName)@$($Credential.GetNetworkCredential().Domain)"
    }
    else
    {
        $sc.ConnectAsUserName = $Credential.GetNetworkCredential().UserName
    }
    $sc.ConnectAsUserPassword = $Credential.GetNetworkCredential().Password
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
    $s = New-Object Microsoft.SqlServer.Management.Smo.Server $sc

    $s
}

function Get-SqlInstanceName([string]$Node, [string]$InstanceName)
{
    $pureInstanceName = Get-PureSqlInstanceName -InstanceName $InstanceName
    if ("MSSQLSERVER" -eq $pureInstanceName)
    {
        $Node
    }
    else
    {
        $Node + "\" + $pureInstanceName
    }
}

function Get-PureSqlInstanceName([string]$InstanceName)
{
    $list = $InstanceName.Split("\")
    if ($list.Count -gt 1)
    {
        $list[1]
    }
    else
    {
        "MSSQLSERVER"
    }
}

function Get-SqlAvailabilityGroup([string]$Name, [Microsoft.SqlServer.Management.Smo.Server]$Server)
{
    $s.AvailabilityGroups | where { $_.Name -eq $Name }
}


function Get-ImpersonateLib
{
    if ($script:ImpersonateLib)
    {
        return $script:ImpersonateLib
    }

    $sig = @'
[DllImport("advapi32.dll", SetLastError = true)]
public static extern bool LogonUser(string lpszUsername, string lpszDomain, string lpszPassword, int dwLogonType, int dwLogonProvider, ref IntPtr phToken);

[DllImport("kernel32.dll")]
public static extern Boolean CloseHandle(IntPtr hObject);
'@
   $script:ImpersonateLib = Add-Type -PassThru -Namespace 'Lib.Impersonation' -Name ImpersonationLib -MemberDefinition $sig

   return $script:ImpersonateLib
}

function ImpersonateAs([PSCredential] $cred)
{
    [IntPtr] $userToken = [Security.Principal.WindowsIdentity]::GetCurrent().Token
    $userToken
    $ImpersonateLib = Get-ImpersonateLib

    $bLogin = $ImpersonateLib::LogonUser($cred.GetNetworkCredential().UserName, $cred.GetNetworkCredential().Domain, $cred.GetNetworkCredential().Password, 
    9, 0, [ref]$userToken)

    if ($bLogin)
    {
        $Identity = New-Object Security.Principal.WindowsIdentity $userToken
        $context = $Identity.Impersonate()
    }
    else
    {
        throw "Can't log on as user '$($cred.GetNetworkCredential().UserName)'."
    }
    $context, $userToken
}

function CloseUserToken([IntPtr] $token)
{
    $ImpersonateLib = Get-ImpersonateLib

    $bLogin = $ImpersonateLib::CloseHandle($token)
    if (!$bLogin)
    {
        throw "Can't close token."
    }
}


Export-ModuleMember -Function *-TargetResource
