$CF_LNRoot = "W:\_LN_TEST"
$CF_CN_V8_EXE = "C:\Program Files (x86)\LexisNexis\Concordance\Concordance.exe" 
$CF_CN_V10_EXE = "C:\Program Files (x86)\LexisNexis\Concordance 10\Concordance_10.exe" 
# TO HL105SQL03 (just in case)
#$global:connectionstring = "Server=HL105SPRSQL03\FYI; Database=FYI_Conversions; Integrated Security = True"
# NOTE: Using Windows Auth, so the user probably needs to be in the Domain Administrator group,
# so they automatically get sysadmin access
$global:connectionstring = "Server=HL105SPRCON01\SQLEXPRESS; Database=<DATABASE>; Integrated Security = True"
