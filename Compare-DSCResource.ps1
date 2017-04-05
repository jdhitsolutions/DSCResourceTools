#requires -version 5.0

#compare installed DSC Resources between the authoring computer and a remote server

Function Compare-DSCResource {
    [cmdletbinding(DefaultParameterSetName = "name")]
    Param(
        [Parameter(
            Position = 0,
            Mandatory,           
            HelpMessage = "Enter the name of a DSCResource",
            ParameterSetName = "name"
            )]
        [ValidateNotNullOrEmpty()]    
        [string]$Name,

        [Parameter(ParameterSetName = "name")]
        [string]$ModuleName,
        
        [Parameter(ParameterSetName = "name")]
        [ValidatePattern({^\d+\.\d+})]
        [string]$Version,        
        
        [Parameter(
            ValueFromPipeline,
            ParameterSetName = "obj"
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo[]]$DSCResource,

        [Parameter(
            Mandatory,
            HelpMessage = "Enter the name of a computer or server to test",
            ParameterSetName = "name"
            )]
        [Parameter(
            Mandatory,
            HelpMessage = "Enter the name of a computer or server to test",
            ParameterSetName = "obj"
            )]
        [Alias("CN")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("^\b\S+\b$")]    
        [string]$Computername,
        
        [Parameter(ParameterSetName = "name")]
        [Parameter(ParameterSetName = "obj")]
        [pscredential]$Credential
        
    )
    Begin {
        Write-Verbose "[$((Get-Date).TimeofDay) BEGIN  ] Starting $($myinvocation.mycommand)"
        #hash table of parameters to splat to Invoke-Command
        $icmParams = @{
            Computername = $Computername
            Scriptblock = $null
            ArgumentList = $null
            ErrorAction = 'Stop'
        }
        if ($Credential) {
            Write-Verbose "[$((Get-Date).TimeofDay) BEGIN  ] Using an alternate credential"
            $icmParams.Add("credential",$Credential)
        }
    } #begin

    Process {
        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Using parameter set $($pscmdlet.ParameterSetName)"
        
        if ($pscmdlet.ParameterSetName -eq 'name') {
            #get the DSC Resource
             Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Getting DSC Resource for $Name"
             #params to splat for Get-DSCResource
             $get = @{Name=$Name;erroraction='stop'}

             if ( -Not($PSBoundParameters.ContainsKey("ModuleName")) -AND $PSBoundParameters.ContainsKey("Version")) {
                 #bail out if there is version but not modulename
                 Write-Warning "You specified a version with no module name."
                 Return
             }
             elseif ($PSBoundParameters.ContainsKey("ModuleName") -AND $PSBoundParameters.ContainsKey("Version")) {
                 Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] in module $moduleName version $version"
                $get.add("module",@{modulename=$moduleName;requiredversion=$version})
             }
             elseif ($PSBoundParameters.ContainsKey("ModuleName")) {
                Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] in module $Name"
                $get.add("module",$modulename)
             }
             
             Try {
                $DSCResource = Get-DscResource @get
            }
            Catch {
                Write-Warning "Failed to find a matching DSC Resource"
                write-warning $_.exception.message
                #bail out
                Return
            }
        } #if Name parameter set

        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Comparing with $($Computername.toUpper())"
        foreach ($resource in $DSCResource) {
             Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Name: $($resource.Name) Module: $($resource.module) Version: $($resource.version)"

             $icmParams.Scriptblock = { 
                 Param($name,$modulename,$version)
                 
                 #check for minimum version. If there are later version are installed, then
                 #they will be detected. This won't detect older versions
                 $module = @{ModuleName = $modulename;ModuleVersion=$version}
                 #$module | out-string | write-host -fore yellow
                 
                 $r = Get-DSCResource -name $name -module $module 
                 if ($r) {
                     $r
                 }
                 else {
                     #return an empty object
                     [pscustomobject]@{
                         Name = $null
                         Module = $null
                         Version = $null
                     }
                 }
                }
            $icmParams.ArgumentList = @($resource.name,$resource.module,$resource.version)
             Try {
                $result = Invoke-Command @icmParams            
             }
             Catch {
                throw $_
             }
             
             [pscustomobject]@{
                 Name = $resource.name
                 Module = $resource.module
                 Version = $resource.version
                 RemoteModule = $result.module
                 RemoteVersion = $result.version
                 RemoteComputer = $Computername.toUpper()
             }

        } #foreach resource
        
    } #process

    End {
        Write-Verbose "[$((Get-Date).TimeofDay) END    ] Ending $($myinvocation.mycommand)"

    } #end 

} #close Compare-DSCResource