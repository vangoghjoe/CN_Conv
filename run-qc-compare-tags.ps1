<#
.SYNOPSIS 

.DESCRIPTION

.PARAMETER Name

.PARAMETER Extension

.INPUTS
None. You cannot pipe objects to this script

.OUTPUTS

.EXAMPLE
One or more examples

.EXAMPLE

.LINK

.LINK

#>

param()

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

# need a batch number

# loop over DB's, use the DB id to construct the search results file names
# for each pair, run the 


    $dbStr = "{0:0000}" -f [int]$dbid
    $dcbDir = [system.io.path]::GetDirectoryName($dcbPfn)
    $resFile = "${bStr}_${dbStr}_${VStr}_tagging.txt"