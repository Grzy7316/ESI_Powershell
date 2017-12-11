#Initial Variables
#User INformation 

#Character ID
$CharacterID = "" 
#Developers.Eveonline.com INformation Goes HEre 
$ClientID = ""
$ClientSecret = ""
#SSO Auth Info
#obtain Refresh Token Using POSTMAN or other REST TOOLS 
$RefreshToken = ""
#End User Information 

#System Configs 

#SET Storage Location of EVE API Dump Stuff
$StoragePath = "C:\ESI_DUMP\" #MAke sure this path ends with a backslash 
$AccessToken ="" #This Value Left Blank to be populated 
#$CallbackUrl = "https://localhost/callback "
$GetNewTokenUrl = "https://login.eveonline.com/oauth/token?grant_type=refresh_token&refresh_token="+$RefreshToken
$ESIURL = "https://esi.tech.ccp.is/latest/"
###########################
#End System Configs 


#This Function allows you to renew an Auth Token with a refresh Token stored  in the $RefreshToken VAriable
Function GetAuthToken
{


#BAse64 Encoding Stuff For Authorization Requests
$Authstring1 = $ClientID+":"+$ClientSecret
$Authstring1
$Text = $Authstring1
$Bytes = [System.Text.Encoding]::Default.GetBytes($Text)
$EncodedText =[Convert]::ToBase64String($Bytes)

 $EncodedText
#End SSO Auth Information


#Set Headers for Token Request.
$header = @{
}
$header.Add('Authorization','Basic '+  $EncodedText  )
$header.Add('Content-Type','application/x-www-form-urlencoded' )
#End Request header 

#Request new Autorization Token
$TEST = Invoke-WebRequest  -UseBasicParsing -Uri $GetNewTokenUrl -Headers $header -Method Post

$AuthkeyObj = ConvertFrom-JSON $TEST #Convert to Powershell Object from JSON 
#$Authkey is new Token 
$Authkey = $AuthKeyObj|Select-Object -ExpandProperty "access_token"
$Seconds = $AuthKeyObj|Select-Object -ExpandProperty "expires_in"
$ts = New-TimeSpan -Seconds $Seconds
$ExpirationTime = (get-date) + $ts
$AuthTracking = New-Object -Typename psobject -Property @{Authkey=$Authkey;Expiry=$ExpirationTime }
#Writes Token & Expiration time to File for storage
Export-CSV -NoTypeInformation -InputObject $AuthTracking -Path $StoragePath"AuthkeyStuff.csv"

}



#This Function imports the Auth Token From The Stored CSV and checks if it is valid 
Function CheckAuth
{

$AUTHINFO = Import-CSV "E:\EVE API\Powershell Storage\AuthkeyStuff.csv"
$AuthExpiry =  $AuthINFO|Select-Object -ExpandProperty Expiry 
$CurrentTime = Get-Date
#If token is Expired, uses GetAuthToken to Acquire new Auth  Token 
if ([DateTime]$AuthExpiry -le [DateTime]$CurrentTime) 
{
GetAuthToken
$AccessToken = $AuthINFO|Select-Object -ExpandProperty Authkey
}
Else
{
    #If token is valid, does not replace token 
$AccessToken = $AuthINFO|Select-Object -ExpandProperty Authkey

}
#Returns AccessToken 
return $AccessToken
} 






Function WalletBalance  #This Pulls Your Current Walletbalance & Dumps the balance & Timestamp to a CSV 
{
   
    $AccessToken = CheckAuth 
    $WalletQuery =  $ESIURL+ "characters/"+$CharacterID+"/wallet/?datasource=tranquility&token="+$AccessToken
   $WalletBalance = Invoke-WebRequest -URI $WalletQuery
   $WalletObj = ConvertFrom-JSON $WalletBalance
#    $WalletObj|out-Gridview 
#    $WalletObj | Get-Member 
   $Currentbalance =  $WalletObj 


  $BalanceOutput =  New-Object -Typename psobject -Property @{Balance=$WalletObj;Datetime=get-date }
    Export-CSV -Append -NoTypeInformation  -InputObject $BalanceOutput -Path $StoragePath"WalletBalance.CSV"

}

Function JournalEntries #This Grabs Journal Entries 
{
$AccessToken = CheckAuth 
$JournalQuery =    $ESIURL+ "characters/"+$CharacterID+"/wallet/journal/?datasource=tranquility&token="+$AccessToken
$JournalTransactions =  Invoke-WebRequest -URI $JournalQuery

$JournalObj = ConvertFrom-JSON -InputObject $JournalTransactions

([pscustomobject]$JournalObj) | export-csv -NoTypeInformation  -Append -Path $StoragePath"Journal.CSV"

}

Function CharacterTransactions #This grabs all Transactions 
{
    $AccessToken = CheckAuth 
    $TransQuery =  $ESIURL+ "characters/"+$CharacterID+"/wallet/transactions/?datasource=tranquility&token="+$AccessToken
    $Transactionlog =  Invoke-WebRequest -URI $TransQuery
    $TransObj = ConvertFrom-JSON -InputObject  $Transactionlog
    ([pscustomobject]$TransObj) | export-csv -NoTypeInformation  -Append -Path $StoragePath"Transactions.CSV"

}


Function CharacterOrders #This Grabs your orders & A timestamp, then appends to a file 
{
    $AccessToken = CheckAuth 
    $OrderQuery = $ESIURL+ "characters/"+$CharacterID+"/orders/?datasource=tranquility&token="+$AccessToken
    $Orderlog =  Invoke-WebRequest -URI $OrderQuery
    $OrderObj = ConvertFrom-JSON -InputObject $Orderlog
    
#  Add-member -InputObject ([pscustomobject]$OrderObj)   -NotePropertyName Timestamp -NotePropertyValue Get-Date
 ([pscustomobject]$OrderObj) |Select-Object *,@{Name='Timestamp';Expression = {get-date} } | export-csv -NoTypeInformation  -Append -Path $StoragePath"Orders.CSV"
}




 WalletBalance 
 JournalEntries
 CharacterTransactions
CharacterOrders