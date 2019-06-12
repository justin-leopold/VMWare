<#  
    .SYNOPSIS  
        Sets VMs to a certain tag. 
    .DESCRIPTION  
        Cleans Sets VMs to a certain tag, is currently not a function or module but should be
        re-worked to do so
    .NOTES  
        File Name   : Remove-UnusedStorage.ps1  
        Author      : Justin Leopold - 3/12/2018
        Written on  : Powershell 6.2
        Tested on   : Powershell 6.2
        Requires    : VMware.PowerCLI
    .LINK  
    #>

    Class TagNames : System.Management.Automation.IValidateSetValuesGenerator {
        [String[]] GetValidValues() {
            $TagNames = (Get-Tag).Name
                            
            return [string[]] $TagNames
        }
    }
    Function Set-VMTags {
        [CmdletBinding()]
        param
        (
            #Virtual machine name
            [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
            [string[]]$Vms,
        
            #vCenter Server Name
            [Parameter(Mandatory)]
            [ValidateSet('pdcvcenter', 'sdcvcenter')]
            [string]$vcenterserver,
    
            #Tags, class above gathers info
            [ValidateSet([TagNames])]
            [String]$Tag
        )
    
        $Tag = Get-Tag -Name Tier1
    
        Foreach ($Vm in $VMs) {
            New-TagAssignment -Tag $Tag -Entity $Vm -Server $vcenterserver
        }
    } 
