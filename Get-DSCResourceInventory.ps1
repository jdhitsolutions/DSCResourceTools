#requires -version 4.0

#DSC Resource inventory

Return "this is a development script"

$all = Get-DscResource

#get module detail
measure-command {

$all | Select ImplementedAs,Name,Module,
@{Name="Description";Expression={(Get-Module $_.module -list).description}},
@{Name="version";Expression={(Get-Module $_.module -list).version}}

}

#not very efficient calling Get-Module twice
$all | Foreach {
$mod = Get-Module -name $_.module -list
Select -InputObject $_ ImplementedAs,Name,Module,
@{Name="Description";Expression={$mod.description}},
@{Name="version";Expression={$mod.version}}
} | Out-GridView -Title "DSC Resource Inventory"

#by module
$all | Sort Module | 
format-table -GroupBy @{Name="Module";
Expression={"$($_.module) v$((Get-Module $_.module -list).version[0])"}} -Property ImplementedAs,Name,Properties

#implemented
$all | Sort ImplementedAs,Name -desc | group ImplementedAs

#hard to sort
$all | Sort ImplementedAs -desc | 
Format-Table -GroupBy ImplementedAs -Property Name,Module,Properties

#sort by name then group
#each group is piped by grouping which is already sorted
$all | sort Name | Group ImplementedAs | Sort Name |
select -ExpandProperty group | 
format-table -group ImplementedAs -Property Name,Module,Properties


#by category
$all | Add-Member -MemberType ScriptProperty -Name "Category" -Value {
 Switch -Regex ($this.name) {
 "(^x\w+)|(_x\w+)" {"Experimental"}
 "(^c\w+)|(_c\w+)" {"Community"}
 Default {"Standard"}
 }
} -PassThru -force | sort Category,Name | 
format-table -GroupBy Category

