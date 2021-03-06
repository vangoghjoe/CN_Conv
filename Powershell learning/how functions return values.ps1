# aha
# write (aka write-output) puts something in the output pipeline
# PS returns everything put there, NOT just the last line or what's after the return statement
# if you output more than one thing, it gets wrapped in an array
function f1() {
    write "hi"
    2
}

function f2() {
    $c = 5
    $d = "bye"
    
    ($c, $d)
}

($a, $b) = f1
write-host $a # => "hi"
write-host $a.GetType()

($x1, $x2) = f2
write-host $x1