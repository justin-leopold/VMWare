Function Remove-UnusedStorage {
    <#  
    .SYNOPSIS  
        Frees up space on a VMFS store so a SAN array marks it as available. 
    .DESCRIPTION  
        Cleans up VMFS datastores and write zeros to the free space to the storage array marks the space as free.
        Applies to VMWare ESXi 5.1, 5.5 and 6.0.VMWare.VimAutomation.Core
    .NOTES  
        File Name   : Remove-UnusedStorage.ps1  
        Author      : Justin Leopold - 3/12/2018
        Written on  : Powershell 5.1
        Tested on:    Powershell 5.1
    .LINK  
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [string]$Vcentername,
        [string]$VMHost
    )
            
    $Rest = "500"                         
    #below sets the vmfs block value. Default is 200
    $blocks = "300"

    #Load snap-in if it's not present
    If ((Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null ) { 
        Add-PSSnapin VMware.VimAutomation.Core 
    }
    
    #begin issuing commands
    Connect-VIServer -Server $HostName
    $HostEsxCli = Get-EsxCli -VMHost $HostName
    $DataStores = Get-Datastore | Where-Object {$_.ExtensionData.Summary.Type -eq 'VMFS' -And $_.ExtensionData.Capability.PerFileThinProvisioningSupported}
    ForEach ($DStore in $DataStores) { 
        Write-Host " ------------------------------------------------------------ " -ForegroundColor 'yellow'
        Write-Host " -- Starting Unmap on DataStore $DStore -- " -ForegroundColor 'yellow' 
        Write-Host " ------------------------------------------------------------ " -ForegroundColor 'yellow'
        $HostEsxCli.storage.vmfs.unmap($blocks, "$DStore", $null)
        Write-Host " ------------------------------------------------------------ " -ForegroundColor 'green'
        Write-Host " -- Unmap has completed on DataStore $DStore -- " -ForegroundColor 'green'
        Write-Host " ------------------------------------------------------------ " -ForegroundColor 'green'
        Start-Sleep -Seconds $Rest
    }
}
