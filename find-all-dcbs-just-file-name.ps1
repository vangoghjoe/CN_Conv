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

# remote 7/8 6:06A

param($Directory)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


# First, find all files with .dcb extension
# Second, filter out ones where 
#  1) named -notes.dcb or -redlines.dcb
#  2) there exists a file with the same name, but without the -notes or -redlines part
$fileObjs = CF-Find-ListOfFilesByExt $Directory ".dcb"

foreach ($fileObj in $fileObjs) {
    $pfn = $fileObj.fullname

    if ($pfn -match "-notes.dcb$") {
        $testMain = $pfn -replace "-notes.dcb$", ".dcb"
        if (Test-Path $testMain) { continue }
    }
    if ($pfn -match "-redlines.dcb$") {
        $testMain = $pfn -replace "-redlines.dcb$", ".dcb"
        if (Test-Path $testMain) { continue }
    }

    write $pfn
}
