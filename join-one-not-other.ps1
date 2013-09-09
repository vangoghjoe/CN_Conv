param(
$file1,
$file2,
$delim = '\|'
)

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
            write-host $key
        }
    }
}
    
function Main() {
    $f1_hash = make-hash $file1
    $f2_hash = make-hash $file2
    First-Not-Second $f1_hash $f2_hash
}
Main
