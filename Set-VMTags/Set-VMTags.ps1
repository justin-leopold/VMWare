    <#  
    .SYNOPSIS  
        Sets VMs to a certain tag. 
    .DESCRIPTION  
        Cleans Sets VMs to a certain tag, is currently not a function or module but should be
        re-worked to do so
    .NOTES  
        File Name   : Remove-UnusedStorage.ps1  
        Author      : Justin Leopold - 3/12/2018
        Written on  : Powershell 5.1
        Tested on   : Powershell 5.1
        Requires    : PowerCLI
    .LINK  
    #>
    
$Tier1VMs = "VM1", "VM2"

$Tag = Get-Tag -Name Tier1

Foreach($Vm in $Tier1VMs){
    New-TagAssignment -Tag $Tag -Entity $Vm
    }
} 