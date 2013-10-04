git filter-branch --index-filter \
    'git rm --cached --ignore-unmatch Data\ Archiving/SQL/Hogan_Data_Archiving_copyonly' \
        --tag-name-filter cat -- --all
