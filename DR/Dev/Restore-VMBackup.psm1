<#
    .SYNOPSIS
    Restores a VM to the SDC infrastructure from Veeam backups
    .DESCRIPTION
    Restores a VM to the SDC infrastructure from Veeam backups.
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
    Online version: https://repo.dpsk12.org/justin_leopold/VmWare/blob/master/DR/Dev/Restore-VMBackup.psm1
#>

#TODO, param/function block complete tests
Function Restore-VMBackup {
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

        <#Veeam Server Name
        [Parameter(Mandatory)]
        [ValidateSet('veeamserver')]
        [string]$VeaamServer,#>

        #Destination Folder Name
        [Parameter(Mandatory)]
        [string]$DestinationFolder,

        #Destination Network
        [Parameter(Mandatory = $true)]
        [ValidateSet('Networkdes', 'isolatedNetwork')]
        [string]$BubbleNetwork

    )
        
    <#Future use, dynamic param for hosts
        DynamicParam{

        }
            process {
                Get-VMHost
            }
         #>
    

    #Uncomment this section only if deploying to a new build engine or workstation,
    #Posh v4 or lower and Veeam Console required on run machine
    #Setup to run on sw-veeam10-p
    #set-alias installutil C:\Windows\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe
    #installutil 'C:\Program Files\Veeam\Backup and Replication\Console\Veeam.Backup.PowerShell.dll'


    #Credentials 
    #TODO, encrytped user creds on build engine
    #TODO update Veeam environments to match
    $Cred = Get-credential -Message "Enter Credentials that are valid for Veeam and vCenter"
    Connect-VBRServer -Server veeamserver -Credential $Cred

    <#Scan and Sync Backups, only needs to be done one time. Takes a couple minutes
    $BackupRepositories = Get-VBRBackupRepository | Where-Object type -ne "WinLocal"
    Foreach ($Repo in $BackupRepositories) {
        Sync-VBRBackupRepository -Repository $Repo
    }#>

    #Write-Output "Script is paused to allow sync to complete. This takes roughly 3 minutes"
    #Start-Sleep -Seconds 200
    Write-Output "Sync Complete, VM is beginning the restore process. This may take a long time"

    #Find VM and Information for restore
    $RestorePoint = Get-VbrRestorePoint -Name $VM | Sort-Object creationtime | select -last 1
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
    Write-Output "Restore Complete, final ip address changes are being made. You will be prompted for local credentials"
    Connect-VIServer $vcenterserver -Credential $cred
    $VMcheck = Get-VM -Name $Vm
    While($VMcheck.Name -ne $Vm) {
        Start-Sleep -Seconds 30
        Write-Output "Sleeping"
        }


    $DestPortGroup = Get-VDPortGroup -Name $BubbleNetwork
    Get-VM $VM | Get-networkAdapter | Set-NetworkAdapter -NetworkName $DestPortGroup -StartConnected:$true -Confirm:$true
    Start-VM -VM $VM -Confirm:$false

    Start-Sleep -Seconds 15

    $guestcred = get-credential -Message "Input local admin or root credentials"
    #$scripttextremove = "Get-NetIPAddress -PrefixLength 24 | Get-NetIPAddress -PrefixLength 24 | Remove-NetIPAddress"
    $scripttextdhcp = "Set-NetIPInterface -InterfaceAlias Ethernet0 -DHCP enabled"
    $scripttextdns = "Set-DnsClientServerAddress -ResetServerAddresses -InterfaceAlias Ethernet0"
    $RemoveNetRoute = "Get-NetIPAddress -InterfaceAlias Ethernet0 | Remove-NetRoute -Confirm:`$false"

    Invoke-VMScript -ScriptText $scripttextdhcp -ScriptType Powershell -VM $VM -GuestCredential $guestcred
    Start-Sleep -Seconds 3
    Invoke-VMScript -ScriptText $scripttextdns -ScriptType Powershell -VM $VM -GuestCredential $guestcred
    Start-Sleep -Seconds 3
    #Below throws an error but does work
    Invoke-VMScript -ScriptText $RemoveNetRoute -ScriptType Powershell -VM $Vm -GuestCredential $guestcred
    Start-Sleep -Seconds 10
    Restart-VM -VM $VM -Confirm:$false

}#close function