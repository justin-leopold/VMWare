#Requires -pssnapin VeeamPsSnapin
#Requires -modules VMWare.VimAutomation.Core

Function Restore-VMBackup {

    <#
    .SYNOPSIS
    Restores a VM to the DR infrastructure from Veeam backups
    .DESCRIPTION
    Restores a VM to the DR infrastructure from Veeam backups.
    Useful in the case of a DR scenario as well as moving VMs into
    the isolated "bubble" networks to test a scenario
    .PARAMETER  Vm
    The name of the virtual machine to be restored. Must match the Veeam backup name.
    .PARAMETER vCenter
    The name of the vCenter server you want to use to restore the VM.
    .PARAMETER VmHost
    The name of the VM Host you want to use to restore the VM. 
    .PARAMETER VeeamServer
    The name of the Veeam Server you want to use to perform the restore.
    .PARAMETER DestinationFolder
    The name of the Folder where the restored Vms will reside on the destination vCenter instance.
    .PARAMETER BubbleNetwork
    The name of the bubble network at DR where the VM will reside.
    .EXAMPLE
    Restore-VMBackup

    .EXAMPLE
    C:\PS> extension -name "File" -extension "doc"
    File.doc

    .EXAMPLE
    C:\PS> extension "File" "doc"
    File.doc

    .LINK
    Online version: https://github.com/justin-leopold/VMWare/tree/master/DR/Dev
#>

    [CmdletBinding()]
    Param
    (
        #Virtual machine name
        [Parameter(Mandatory,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $True)]
        [string]$Vm,

        #vCenter Server Name
        [Parameter(Mandatory)]
        [ValidateSet('vcenter1', 'vcenter2')]
        [string]$vCenterServer,

        #Vm Host Name
        [Parameter(Mandatory)]
        [ValidateSet('host', 'host2', 'host3')]
        [string]$VmHost,

        #Veeam Server Name
        [Parameter(Mandatory)]
        [ValidateSet('veeamserver')]
        [string]$VeaamServer,

        #Destination Folder Name
        [Parameter(Mandatory)]
        [string]$DestinationFolder,

        #Destination Network
        [Parameter(Mandatory = $true)]
        [ValidateSet('Networkdes', 'isolatedNetwork')]
        [string]$BubbleNetwork,

        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $LocalCredential = [System.Management.Automation.PSCredential]::Empty

    )
   
    #Credentials and SnapIn
    Add-PSSnapin VeeamPsSnapin
    Connect-VBRServer -Server $VeeamServer -Credential $Credential

    #Find VM and Information for restore
    $RestorePoint = Get-VbrRestorePoint -Name $VM | Sort-Object creationtime | Select-Object -last 1
    Write-output "RP"
    $DestDatastore = Find-VBRViEntity -DatastoresAndVMs | Where-Object name -like "*destdatastores*"
    Write-output "DS"
    $Resources = Find-VBRViEntity -ResourcePools -Server $vcenterserver -Name Resources
    Write-output "RPool"
    $FolderList = Find-VBRViFolder -Server $vcenterserver
    $Folder = $folderlist | Where-Object name -like $DestinationFolder

    Write-Output "Variables set, Vm restoring now"
    #Restore the VM, doesn't have an option for network, see below
    Start-VBRRestoreVM -VMName $VM -ResourcePool $Resources -Folder $Folder -DiskType Source -Datastore $DestDatastore[0] -RestorePoint $RestorePoint[0] -Server $VmHost -PowerUp:$false

    #Bring the guest VM back online after a restore
    Write-Verbose "Restore Complete, final ip address changes are being made."
    Connect-VIServer $vcenterserver -Credential $Credential
    $VMcheck = Get-VM -Name $Vm
    While ($VMcheck.Name -ne $Vm) {
        Start-Sleep -Seconds 30
        Write-Output "Sleeping"
    }


    $DestPortGroup = Get-VDPortGroup -Name $BubbleNetwork
    Get-VM $VM | Get-networkAdapter | Set-NetworkAdapter -NetworkName $DestPortGroup -StartConnected:$true -Confirm:$true
    Start-VM -VM $VM -Confirm:$false

    Start-Sleep -Seconds 15

    $scripttextdhcp = "Set-NetIPInterface -InterfaceAlias Ethernet0 -DHCP enabled"
    $scripttextdns = "Set-DnsClientServerAddress -ResetServerAddresses -InterfaceAlias Ethernet0"
    $RemoveNetRoute = "Get-NetIPAddress -InterfaceAlias Ethernet0 | Remove-NetRoute -Confirm:`$false"

    Invoke-VMScript -ScriptText $scripttextdhcp -ScriptType Powershell -VM $VM -GuestCredential $LocalCredential
    Start-Sleep -Seconds 3
    Invoke-VMScript -ScriptText $scripttextdns -ScriptType Powershell -VM $VM -GuestCredential $LocalCredential
    Start-Sleep -Seconds 3
    #Below throws an error but does work
    Invoke-VMScript -ScriptText $RemoveNetRoute -ScriptType Powershell -VM $Vm -GuestCredential $LocalCredential
    Start-Sleep -Seconds 10
    Restart-VM -VM $VM -Confirm:$false

}#close function

Function Sync-BackupRepository {
    <#
    .SYNOPSIS
    Syncs Veeam backup repositories at the DR site. 
    .DESCRIPTION
    Syncs Veeam backup repositories at the DR site. This should be done before using other
    commands in this module if sync is not regularly scheduled. 
    .PARAMETER  RepositoryFilter
    The name or partial name of the repository type that needs to be synced.
    .PARAMETER  VeeamServer
    The Veeam Server where the repository is located. 
    .EXAMPLE
    C:\PS> extension -name "File" -extension "doc"
    File.doc

    .LINK
    Online version: https://github.com/justin-leopold/VMWare/tree/master/DR/Dev
#>

    [CmdletBinding()]
    Param
    (
        #Repo Filter on type
        [Parameter]
        $RepositoryFilter,

        #Veeam Server Name
        [Parameter(Mandatory)]
        [ValidateSet('veeamserver')]
        [string]$VeaamServer,

        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    Add-PSSnapin VeeamPsSnapin
    Connect-VBRServer -Server $VeeamServer -Credential $Credential

    #Scan and Sync Backups, only needs to be done one time. Takes a couple minutes
    $BackupRepositories = Get-VBRBackupRepository | Where-Object type -like "*$RepositoryFilter*" 
    Foreach ($Repo in $BackupRepositories) {
        Sync-VBRBackupRepository -Repository $Repo
    }
}#func