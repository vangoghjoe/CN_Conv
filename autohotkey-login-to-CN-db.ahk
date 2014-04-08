; mode 3 = exact match
SetTitleMatchMode 3 
SendMode Input

EnterCreds(dbname,name, pwd)
{
	; If no args, go to Last Found Window
	WinActivate %dbname%
	MouseMove, 113,38
	MouseClick
    sleep 1000
	Send {Home}
    sleep 1000
	Send +{End}
    sleep 1000
	Send %name%
    sleep 1000

	Send {TAB}
    sleep 1000
	Send {Home}
	Send +{End}
	Send %pwd%
    sleep 1000
	Send {ENTER}
}

Login(dbname) 
{
    line = 1
    while 1 
    {
        ; Dialog will be gone if login was successful
        ifWinNotExist %dbname%
        {
            msgbox "win not there"
            break
        }

        FileReadLine name, c:\conv_creds.txt, %line%

        ; No more creds to try
        ; Cancel the dialog and exit the loop
        if errorlevel
        {
            ;msgbox "hit errorlevel"
            Send {ESC}
            break
        }

        ;msgbox "name = " %name%
        FileReadLine pwd, c:\conv_creds.txt, (line+1)
        ;msgbox "pwd = " %pwd%
        EnterCreds(dbname, name, pwd)
        sleep 1000
        line := line + 2
    }
}

while 1
{
    FileReadLine dbname,c:\current_dbname.txt, 1
    ; should trim it b/c AutoTrim is on by default
    dbname = %dbname%

    ifWinExist %dbname%
    {
       Login(dbname) 
    }

    sleep 1000
}

