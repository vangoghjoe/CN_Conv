<#
#$a = 5

function b () {
    write "in b: before $a"
    $a = 8
    write $a
    c
    d
}

function d() {
    $a = 9
    c
}
function c () {
    write "in c: $local:a"
}

#remove-variable a
$a = 5
b

write "after b: a = $a"
#>


<#
function b([ref]$x) { 
    $x.value += 1
}

$a = 1
write "a before: $a"
b([ref]$a)
write "a after: $a"
#>

<#
try {
    throw "my error"
}
catch {
    $err1 = $error[0]
    $err2 = $_.Exception.Message
    write "err1 = $err1"
    write "err2 = $err2"
}
#>

function f(a, b, c) { 
    write "b = $b   a = $a  c = $c" 
}

f 1 2 3




