param (
    [string] $oldTagFile,
    [string] $newTagFile
 )

# local 7/17 11:05A

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

# format of tag file
## tab delimited
## 1: search number
## 2: num hits
## 3: num docs
## 4: search term (tag)

function build-tag-table {
    param (
        [string] $tagFile,
        [string] $version
    )
    $srchnum = ""
    $hits = 0
    $docs = 0
    $tag = ""
    
    $lines = Get-Content $tagFile
    
    $hash = @{}
    foreach ($line in $lines) {
        # first line should be <Entire Database>, 
        # then lines like "»Tagging My tag«"
        # finally, likes  1 or 2 or 3
        # Only care about the Tagging lines, 
        # meaning first char of tag field is a quote
        # TODO: might as well out all but the actual tag name
        $line = $line.ToUpper()
        ($srchNum, $hits, $docs, $tag) = $line.split("`t")
        
        # Only care about the Tagging lines, 
        # meaning first char of tag field is a quote
        if ($tag.substring(0,1) -eq '"') {
            # in v8, default tag is just called Tagging, so change it to same name
            # as in v10
            if ($version -eq "v8" -and ($tag -eq '"»Tagging«"')) {
                $tag = '"»TAGGING DEFAULT TAG«"'
            }
            # in the hash: $tagname = [ [num hits, num docs], searchnumber ]
            $hash[$tag] = @( @($hits,$docs), $srchNum)
        }  
        #$x
            
    }
    return $hash
}


function compare-tables {
    param (
        $tags1,
        $tags2,
        $pass
    )
    
    # $pass = pass1 means old 2 new
    # $pass = pass2 means new 2 old; in pass2, we don't compare tag values

    if ($pass -eq "pass1") { $desc = "old2new" } else { $desc = "new2old" }

    
    #TODO: rename this variables: 
    # $tag1Name = $tag1Name  $tag1Info = $tags1[$tag1Name]
    foreach ($h in $tags1.GetEnumerator()) {
        if ($tags2.ContainsKey($h.Name)) {
            $val1 = $tags1[$h.Name][0]
            if ($pass -eq "pass1") {
                $searchNum1 = $tags1[$h.Name][1]
                $val2 = $tags2[$h.Name][0]
                $searchNum2 = $tags2[$h.Name][1]
                
                # compare-object arr1 arr2 -syncwindow
                #  => if same, returns null, else returns the different elems
                $diffs = compare-object $val1 $val2 -syncwindow 0
                if ($diffs) {
                    $msg = "DIFF COUNTS ($desc): tag = $($h.name) |"
                    $msg += "$val1 [search $searchNum1]|"
                    $msg += "$val2 [search $searchNum2]"
                    write $msg
                    $script:errct += 1
                }
            }
        }
        else {
            # tag in 1 but not 2
            
            # Exception: if v8 had the Default tag 
            # (renamed to Tagging Default Tag when building tag table), with no hits
            # it won't be converted to v10,so that's not an error
            if ( ($h.Name -eq '"»Tagging Default tag«"') -and ($pass -eq "pass1") ) {
                $val1 = $tags1[$h.Name][0];
                $hits = $val1[0];
                $docs = $val1[1];
                if (($hits -eq "0" -and $docs -eq "0")) {
                    continue
                }
            }
            
            write "FIRST, NOT SECOND ($desc): $($h.Name)"
            $script:errct += 1
        }
    }
}


$script:errct = 0
$oldTags = build-tag-table $oldTagFile "v8"
$newTags = build-tag-table $newTagFile "v10"

compare-tables $oldTags $newTags "pass1"
compare-tables $newTags $oldTags "pass2"

# if no errors, give the all clear
if ($script:errct -eq 0) {
    write "|EXIT STATUS|OK"
}
else {
    write "|EXIT STATUS|FAILED"
}
    