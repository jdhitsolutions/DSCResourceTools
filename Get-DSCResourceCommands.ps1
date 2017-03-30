#requires -version 4.0

<#
Parse a DSC Resource module and report what commands and modules it requires.
This can be useful in determining if a given resource will work on a node.
The function won't detect the use of aliases or command line tools,
#>
Function Get-DSCResourceCommands {
[cmdletbinding()]
Param(
[Parameter(Position=0,Mandatory,HelpMessage="Enter the name of a DSC resource")]
[ValidateNotNullorEmpty()]
[string]$Name)

Begin {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"  
    #define a regular expression to pull out cmdlet names using some common verbs
    [regex]$rx="\b(Get|New|Set|Add|Remove|Test|Stop|Start|Invoke|exe)-\w+\b"
} #begin

Process {
    Write-Verbose "Getting DSC Resource $Name"
        Try {
            $resource = Get-DscResource -Name $name -ErrorAction Stop
            Write-Verbose ($resource | out-string)
        }

        Catch {
            Throw
        }
        if ($resource) {

        #get the code from the module path which will be something like this:
        #'C:\Program Files\WindowsPowerShell\Modules\xSmbShare\DSCResources\MSFT_xSmbShare\MSFT_xSmbShare.psm1'
        Write-Verbose "Processing content from $($resource.path)"
        $code = Get-Content -path $resource.path

        #find matching names ignoring standard function names
        #in a DSC Resource like Get-TargetResource
        $rx.matches($code).Value | sort | Get-Unique | 
        Where {$_ -notmatch "-TargetResource$"} | foreach {
          #try to identify the module for a given command
          $Name = $_
          Try {
            $mod = Get-Command -Name $Name -ErrorAction Stop
            $ModuleName = $mod.ModuleName
            $Name = $mod.Name
          }
          Catch {
            Write-Verbose "Failed to resolve module for $name"
            $ModuleName = "Unknown"

          }
          #create a custom object
          [pscustomobject]@{
           Name = $Name
           Module = $ModuleName
          }
        } #foreach


        } #if $resource

} #process

End {
    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
} #end

}
