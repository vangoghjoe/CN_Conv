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

# what would satisfy me on the parallel test?
#if have a number of processes trying to constantly write, like 5 times a second.  
#Each can write their name, a timestamp, and consecutive numbers.  
#If 3 can do it at same time for 10 mins and nobody loses a number, we're good.



