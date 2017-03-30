#requires -version 4.0

<#


#>

Function Get-DSCResourceDetail {

<#
.Synopsis
Create an analysis report for a DSC resource
.Description
This command will parse a DSC resource module and discover the required commands, keywords and typenames. This can be helpful in identifying what the resource will require. The easiest way to use this command is to pipe a resource to it. See Examples

.Example
PS C:\> Get-DSCResource xSMBShare | Get-DSCResourceReport -outvariable c

Name      : xSmbShare
Module    : @{Name=xSmbShare; Description=Module with DSC Resources for SmbShare area; Version=1.1.0.0; 
            RequiredAssemblies=System.Collections.ObjectModel.Collection`1[System.String]; 
            RequiredModules=System.Collections.ObjectModel.ReadOnlyCollection`1[System.Management.Automation.PSModuleInfo]}
Commands  : {@{CommandType=Function; Name=Block-SmbShareAccess; ModuleName=SmbShare}, @{CommandType=Cmdlet; Name=Compare-Object; 
            ModuleName=Microsoft.PowerShell.Utility}, @{CommandType=Cmdlet; Name=Export-ModuleMember; ModuleName=Microsoft.PowerShell.Core}, 
            @{CommandType=Cmdlet; Name=ForEach-Object; ModuleName=Microsoft.PowerShell.Core}...}
Keywords  : {else, elseif, param}
TypeNames : {string, system.boolean, system.collections.hashtable, system.string...}

PS C:\> $c.module

Name               : xSmbShare
Description        : Module with DSC Resources for SmbShare area
Version            : 1.1.0.0
RequiredAssemblies : {}
RequiredModules    : {}

PS C:\> $c.Commands


CommandType Name                    ModuleName                  
----------- ----                    ----------                  
   Function Block-SmbShareAccess    SmbShare                    
     Cmdlet Compare-Object          Microsoft.PowerShell.Utility
     Cmdlet Export-ModuleMember     Microsoft.PowerShell.Core   
     Cmdlet ForEach-Object          Microsoft.PowerShell.Core   
     Cmdlet Get-History             Microsoft.PowerShell.Core   
   Function Get-SmbShare            SmbShare                    
   Function Get-SmbShareAccess      SmbShare                    
   Function Grant-SmbShareAccess    SmbShare                    
     Cmdlet Invoke-History          Microsoft.PowerShell.Core   
   Function New-SmbShare            SmbShare                    
    Unknown Remove-AccessPermission Unknown                     
   Function Remove-SmbShare         SmbShare                    
   Function Revoke-SmbShareAccess   SmbShare                    
    Unknown Set-AccessPermission    Unknown                     
   Function Set-SmbShare            SmbShare                    
   Function Unblock-SmbShareAccess  SmbShare                    
     Cmdlet Where-Object            Microsoft.PowerShell.Core   
     Cmdlet Write-Debug             Microsoft.PowerShell.Utility
     Cmdlet Write-Verbose           Microsoft.PowerShell.Utility


PS C:\> $c.Keywords

else
elseif
param

PS C:\> $c.typenames

string
system.boolean
system.collections.hashtable
system.string
system.uint32

.EXAMPLE
PS C:\> $r = Get-dscresource xsmbshare | Get-DSCResourceDetail
PS C:\> $r | foreach -Begin {$frags = @()} -process {
 $frags = "<H1>$($_.module.name)</H1><br>"
 $frags+= $_.module | Select Name,Description,Version | ConvertTo-HTML -As Table -Fragment -PreContent "<H2>Module</H2>"
 $frags+= $_.module.RequiredAssemblies | ConvertTo-Html -As table -Fragment -PreContent "<H3>Required Assemblies</H3>"
 $frags+= $_.module.RequiredModules | ConvertTo-Html -As List -Fragment -PreContent "<H3>Required Modules</H3>"
 $frags+= $_.Commands | Select CommandType,Name,ModuleName | ConvertTo-Html -Fragment -as table -PreContent "<H2>Commands</H2>"
 $frags+= $_.Keywords | foreach {[pscustomobject]@{Keyword=$_}} | ConvertTo-HTML -Fragment -Property Keyword -PreContent "<H2>Keywords</H2>"
 $frags+= $_.Typenames | foreach {[pscustomobject]@{Type=$_}} | ConvertTo-HTML -Fragment -property Type -PreContent "<H2>Typenames</H2>"
} -end {
 ConvertTo-Html -Body $frags -Title "$($r.module.name) Detail" -CssUri C:\scripts\sample.css | Set-Content c:\work\report.htm
}

Create an HTML report for the xSMBShare resource.
  


.Notes
Version : 1.0

Learn more about PowerShell:
http://jdhitsolutions.com/blog/essential-powershell-resources/


.Link
Get-DSCResource

#>

Param(
[Parameter(
Position=0,
Mandatory,
HelpMessage = "Enter the name of a DSC resource",
ValueFromPipelineByPropertyName
)]
[ValidateNotNullorEmpty()]
#The name of a resource
[string]$Name,

[Parameter(
Mandatory,
HelpMessage = "Enter the name of the resource's module",
ValueFromPipelineByPropertyName
)]
[ValidateNotNullorEmpty()]
#the name of the resources module
[string]$Module = "cActiveDirectory",

[Parameter(
Mandatory,
HelpMessage ="Enter the path to the module base psm1 file",
ValueFromPipelineByPropertyName
)]
[ValidateNotNullorEmpty()]
#The path to the module root
[string]$Path
)


Begin {
    Write-Verbose "[BEGIN  ] Starting: $($MyInvocation.Mycommand)"
    New-Variable astTokens -force
    New-Variable astErr -force
}

Process {

Write-Verbose "[PROCESS] Processing $path"

$AST = [System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$astTokens,[ref]$astErr)

$h = $astTokens | group tokenflags -AsHashTable -AsString

Write-Verbose ("[Process] Details for DSC Resource {0} [{1}]" -f $name,$module)
$moduleDetails = Get-Module $module -list | Select Name,Description,Version,Required*


$CommandDetails = ($h.CommandName).where({$_.text -notmatch "-TargetResource$"}) |
foreach {
 
 #TODO SPECIAL HANDLING FOR ?
 Write-Verbose "[PROCESS] Resolving $($_.text)"
 Try {
     $cmd = $_.Text
     $resolved = $cmd | Get-Command -ErrorAction Stop
     if ($resolved.CommandType -eq 'Alias') {
     
     write-verbose "[PROCESS] alias found for $($resolved.name)"
       $resolved.ResolvedCommandName | Get-Command
 }
 else {
    $resolved
 }
 }
 Catch {
    
  [PSCustomobject]@{
   CommandType = "Unknown"
   Name = $cmd
   ModuleName = "Unknown"
  }
 }
} | Sort Name | Select CommandType,Name,ModuleName -Unique #| Format-Table | Out-String


#Convert to lower case because Get-Unique is case-sensitive
$Keywords = ($h.Keyword.Text).ToLower() | sort | Get-Unique
$TypeNames = ($h.TypeName.Text).ToLower() | sort | Get-Unique

#create a custom object with the resource details
[pscustomobject]@{
 Name = $Name
 Module = $moduleDetails
 Commands = $CommandDetails
 Keywords = $Keywords
 TypeNames = $TypeNames
}

}
End {
    Write-Verbose "[END    ] Ending: $($MyInvocation.Mycommand)"
} #end
} #close function