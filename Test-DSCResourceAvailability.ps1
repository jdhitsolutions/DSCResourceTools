#requires -version 5.0

#test if a given DSC resource is available or will function on a remote server.
#UNDER DEVELOPMENT

Function Test-DSCResourceAvailability {
    [cmdletbinding()]
    Param(
        [Parameter(
            Position = 0,
            Mandatory,
            ValueFromPipeline,
            HelpMessage = "Enter the name of a DSCResource"
            )]
        [ValidateNotNullOrEmpty()]    
        [string]$Name,
        [string]$Module,
        [string]$ModuleVersion,
        [Parameter(
            Mandatory,
            HelpMessage = "Enter the name of a computer or server to test"
            )]
        [Alias("CN")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("^\b\S+\b$")]    
        [string]$Computername,
        [pscredential]$Credential
    )
    Begin {
        Write-Verbose "[$((Get-Date).TimeofDay) BEGIN  ] Starting $($myinvocation.mycommand)"

    } #begin

    Process {
        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Getting DSC Resource: $Name"
        Try {
            $getParams = @{
                ErrorAction = 'Stop'
                Name = $Name
            }
            
            if ($module -AND $ModuleVersion) {
                Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] From module $module version $moduleversion"
                $getParams.Add("module",@{Modulename = "$module";RequiredVersion = "$moduleVersion"})
            }
            elseIf ($Module) {
                Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] From module $module"
                #turn the module back into a hashtable
                $getParams.Add("module",$module)
            }

            $getParams | Out-String | write-verbose
            $global:g = $getParams
            $resource = Get-DSCResource @getParams

             #there might be multiple versions or name conflicts and we should only test for a
            #specific version
            If ($resource.name.count -gt 1) {
                Write-Warning "Found multiple versions of $name."
                Write-Warning ($resource | Out-String  )
                Write-Warning "You must select a specific resource and module."
                #bail out 
                Return
            }
            elseif ($resource.name.count -eq 0) {
                #bail out since resource was not found
                Return
            }
        }
        Catch {
            $global:k = $getParams
            Write-Warning "There was an error getting the resource $Name. $($_.exception.message)"
            #bail out
            Return
        }    

        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Getting DSC Resource detail"
        $detail = Get-DSCResourceDetail -Name $resource.Name -FullyQualifiedName @{ModuleName = $resource.Module.Name;ModuleVersion = $resource.module.version} -path $resource.path

        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Name: $($detail.name)"
        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] ModuleName: $($detail.module.name) Version: $($detail.module.version.toString())"
        $cmds = ($detail.commands).Where({$_.modulename -ne 'unknown'}).name
        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Found $($cmds.count) known commands"
        $global:d = $detail
        #get module details
        $modulefull = Get-Module -ListAvailable -FullyQualifiedName @{ModuleName = $($detail.module.name);ModuleVersion = $($detail.module.version)}
 $global:m = $modulefull   
        $results = [ordered]@{
            DSCResource = $detail.name
            ResourceInstalled = $False
            Module = $modulefull.name
            ModuleVersion = $modulefull.version
            PowerShellHostVersion = $modulefull.powershellhostversion
            PowerShellVersion = $modulefull.powershellversion
            DotNetFrameworkVersion = $modulefull.DotnetFrameworkversion
            ProcessorArchitecture = $modulefull.ProcessorArchitecture
            RequiredAssemblies = $modulefull.RequiredAssemblies
            KnownCommands = $cmds
            FoundCommands = $null
            MissingCommands = $null
            Computername = $Computername
        }
           
        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Testing availability on $($Computername.toUpper())"
        $PSBoundParameters.remove("name") | Out-Null
        $PSBoundParameters.remove("module") | Out-Null
        $PSBoundParameters.remove("moduleversion") | Out-Null
        <#
        if ($ModuleVersion) {
            $modulestring = ($getparams.module -as [Microsoft.PowerShell.Commands.ModuleSpecification]).ToString()
        }
        else {
            $modulestring = $getParams.module
        }
        write-host $name -ForegroundColor cyan
        write-host $modulestring -ForegroundColor cyan
        #>
            $sb = {
                Param($name,$module)
               
                $PSBoundParameters | out-string | write-host -ForegroundColor Magenta
                $PSBoundParameters.remove("__using_cmds")
                $res = Get-DSCresource @PSBoundParameters -ErrorAction Ignore
                <#
                filter command names using Get-Command and save results to variables
                $found will be the command names returned by Get-Command
                $missing will be those names that failed to get a command
                $cmddetail will be the found command details from Get-Command
                #>
                $found,$missing = ($using:cmds).where({Get-Command $_ -erroraction ignore -OutVariable +cmdDetail},'split')

                #write a hashtable of results
                @{
                    Resource = $res
                    Found = $found
                    Missing = $missing
                    Details = $cmdDetail
                }
            }
            $PSBoundParameters.Add("scriptblock",$sb) | Out-Null
            $args = @($name)
            if ($getParams.module) {
                $args+=$getParams.module
            }
            $PSBoundParameters.Add("argumentlist",$args)
            $remote = Invoke-Command @PSBoundParameters 

            $global:q=$remote
            If ($remote.resource) {
                $results.ResourceInstalled = $True
            }            
            $results.Foundcommands = $remote.details
            $results.MissingCommands = $remote.missing
        
            #write the results
            [pscustomobject]$results
    } #process

    End {
        Write-Verbose "[$((Get-Date).TimeofDay) END    ] Ending $($myinvocation.mycommand)"

    } #end 

} #close Name

