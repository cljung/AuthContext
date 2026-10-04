if (Test-Path -Path "../AuthContextWebApp/appsettings.Development.json") {
  $appsettings = (Get-Content "../AuthContextWebApp/appsettings.Development.json" | ConvertFrom-json)
} else {
  $appsettings = (Get-Content "../AuthContextWebApp/appsettings.json" | ConvertFrom-json)
}

# acquire an Entra access token via client credentials
$tenantId = $appsettings.Entra.TenantId
$ClientId = $appsettings.Entra.ClientId
$ClientSecret = $appsettings.Entra.ClientSecret
$Scope = $appsettings.DownstreamAPI.Scopes[0].Replace("access_as_user", ".default")

Write-Host "Acquiring access token for AppID $ClientId" -ForegroundColor Green

$TokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
        -ContentType "application/x-www-form-urlencoded" `
        -Body @{ grant_type="client_credentials"; client_id=$ClientId; client_secret=$ClientSecret; scope=$Scope }
$AccessToken = $TokenResponse.access_token
Write-Host "Successfully authenticated with Entra! Access token received." -ForegroundColor Green
#Write-Host $AccessToken -ForegroundColor white
$Headers = @{ "Authorization"="Bearer $AccessToken"; "Accept"="application/json" }

$url = "$($appsettings.DownstreamAPI.BaseUrl)/api/sensitiveoperation"
Write-Host "Calling API $url using app access token" -ForegroundColor Green

$ApiResponse = Invoke-RestMethod -Uri $url -Method Get -Headers $Headers -SkipCertificateCheck 
$ApiResponse