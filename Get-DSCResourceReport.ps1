#requires -version 4.0

Function Get-DscResourceReport {

<#
.Synopsis
Create an analysis report for a DSC resource
.Description
This command will parse a DSC resource module and prepare a textual report about required commands, keywords and typenames. This can be helpful in identifying what the resource will require. The easiest way to use this command is to pipe a resource to it. See Examples

Note: This command does not write a simple object to the pipeline but rather formatted text.

.Example
PS C:\> Get-DSCResource xSMBShare | Get-DSCResourceReport

Details for DSC Resource xSmbShare [xSmbShare]

Name               : xSmbShare
Description        : Module with DSC Resources for SmbShare area
Version            : 1.1.0.0
RequiredAssemblies : {}
RequiredModules    : {}


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



Keywords
--------
else
elseif
param

TypeNames
---------
string
system.boolean
system.collections.hashtable
system.string
system.uint32


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
[string]$Module,

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

"Details for DSC Resource {0} [{1}]" -f $name,$module
Get-Module $module -list | Select Name,Description,Version,Required*


($h.CommandName).where({$_.text -notmatch "-TargetResource$"}) |
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
} | Sort Name | Select CommandType,Name,ModuleName -Unique | Format-Table | Out-String


#Convert to lower case because Get-Unique is case-sensitive
"Keywords"
"--------"
($h.Keyword.Text).ToLower() | sort | Get-Unique

"`nTypeNames"
"---------"
($h.TypeName.Text).ToLower() | sort | Get-Unique

}
End {
    Write-Verbose "[END    ] Ending: $($MyInvocation.Mycommand)"
} #end
} #close function