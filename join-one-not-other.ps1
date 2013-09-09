param(
$file1,
$file2,
$outFile,
$delim = '\|'
)

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

function Make-Hash($file) {
    $recs = get-content $file
    $h = @{}
    foreach ($rec in $recs) {
        $p = $rec -split $delim
        $h[$p[0]]=""
    }
    return $h
}

function First-Not-Second($h1, $h2) {
    foreach ($key in $h1.Keys) {
        if (-not ($h2.ContainsKey($key))) {
            CF-write-file $outFile $key
        }
    }
}
    
function Main() {
    rm $outFile 2>&1 > $null
    $f1_hash = make-hash $file1
    $f2_hash = make-hash $file2
    First-Not-Second $f1_hash $f2_hash
}
Main
