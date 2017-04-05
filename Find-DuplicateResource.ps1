#requires -version 5.0

#find duplicate resources by name



Function Find-DuplicateDscResource {
    [cmdletbinding()]
    Param(
        [string]$Computername,
        [pscredential]$Credential
    )

    Begin {
        Write-Verbose "[$((Get-Date).TimeofDay) BEGIN  ] Starting $($myinvocation.mycommand)"
        $sb = {
            $all = Get-DscResource
            Write-Host "Found $($all.count) DSC resources on $($env:computername)" -ForegroundColor green
            $dupes = $all | Group-Object -property name | Where-Object count -gt 1 | Sort-Object count -Descending
            Write-Host "Found $($dupes.count) multiple instances of DSC resources" -foreground green
            $dupes.group | 
            Select-object -property @{Name='Computername';Expression = {$env:computername}},Name,ModuleName,Version
       
        }
        $PSBoundParameters.Add("scriptblock",$sb)

        If ($Computername) {
        $PSBoundParameters.Add("HideComputername",$True)
        Write-Verbose "[$((Get-Date).TimeofDay) BEGIN  ] Searching $Computername"
        }
    } #begin

    Process {
        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Finding duplicate Dsc resources"
        #$PSBoundParameters | out-string | write-host -ForegroundColor Gray
      
       Invoke-Command @PSBoundParameters | Select-Object -Property Computername,Name,ModuleName,Version
          
    } #process

    End {
        Write-Verbose "[$((Get-Date).TimeofDay) END    ] Ending $($myinvocation.mycommand)"

    } #end 

} #close Find-DuplicateDscResource