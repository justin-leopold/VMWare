<#  
.SYNOPSIS  
    Connects to the Tegile API and gets disks from the project and creates datastores via vCenter.  
.DESCRIPTION  
    This connects to the API of the Tegile AFA and connects to a specific project and gets the LUNs. 
    If there are LUNs that are not mounted in ESXi, then they are added. There is some amount of user interaction.
    This may be removed in a future revision.
.NOTES  
    File Name   : Add-NewDatastore.ps1  
    Author      : Justin Leopold - 11/15/2018
    Written on  : Powershell 5.1
    Tested on:    Powershell 5.1
.LINK  
#>

$bytes = [System.Text.Encoding]::UTF8.GetBytes("user:password")
$token = [System.Convert]::ToBase64String($bytes)
$headers = @{"Authorization"="Basic $token"; "Content-Type"="application/json"}
$url = "https://sip-tegile2.dpsk12.org/zebi/api/v2/listProjects"
$method = "POST"
[System.Net.ServicePointManager]::ServerCertificateValidationCallback ={$TRUE}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
$parameters = "pool-b","true"
$jsonString = ConvertTo-Json -Compress -Depth 2 $parameters
$jsonString
$projects = Invoke-RestMethod -Method $method -Headers $headers -Uri $url -Body $jsonString
$projects



#$bytes = [System.Text.Encoding]::UTF8.GetBytes("user:password")
#$token = [System.Convert]::ToBase64String($bytes)
$headers = @{"Authorization"="Basic $token"; "Content-Type"="application/json"}
$url = "https://tegile.domain.org/zebi/api/v2/listVolumes"
$method = "POST"
[System.Net.ServicePointManager]::ServerCertificateValidationCallback ={$TRUE}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
$parameters = "pool-b","Temp1","true"
$jsonString = ConvertTo-Json -Compress -Depth 3 $parameters
$jsonString
$Luninformation = Invoke-RestMethod -Method $method -Headers $headers -Uri $url -Body $jsonString 
$Luninformation.LuId


#Cross reference with vCenter
#$vmcred = get-credential
Connect-VIServer -Server pdcvcenter -Credential $vmcred
Foreach($lun in $Luninformation) {
    Get-Datastore -Name $lun.name
}
#this is a thing for correlating between two commands

$esxName = "hostdnsname"

$dsTab = @{}
foreach($ds in (Get-Datastore -VMHost $esxName | Where-Object {$_.Type -eq "vmfs"})){
    $ds.Extensiondata.Info.Vmfs.Extent | %{
        $dsTab[$_.DiskName] = $ds.Name
    }
}

$report = @()
Get-ScsiLun -VmHost $esxName -LunType "disk" | Foreach{

    $row = "" | Select-Object Host, ConsoleDeviceName, Vendor, Model, Datastore
    $row.host = $esxName
    $row.ConsoleDeviceName = $_.ConsoleDeviceName.TrimStart('/vmfs/devices/disks/naa.')
    $row.vendor = $_.Vendor 
    $row.model = $_.Model
    $row.Datastore = &{
        if($dsTab.ContainsKey($_.CanonicalName)){
            $dsTab[$_.CanonicalName]
        }
    }
    $report += $row}

$UnusedDatastores = $report | Where-object { $_.Datastore -notlike "pdc-*" -and $_.Model -ne "RAID"}
#| Export-Csv c:\psdrive\results.csv -NoTypeInformation 
$UnusedDatastores.ConsoleDeviceName

New-Datastore -Name $Luninformation[0].name -VMHost pdc-ucsvms01.dpsk12.org -Vmfs -FileSystemVersion 6 -Path naa.$luninformation[0]

ForEach-Object($D in $UnusedDatastores){
    Write-host  "naa.$Luninformation.ConsoleDeviceName"
}
