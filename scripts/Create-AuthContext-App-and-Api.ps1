# Import-Module Microsoft.Graph.Applications
# Connect-MgGraph -Scopes "Application.ReadWrite.All"

$tenantId = (Get-MgContext).TenantId
$apiScopeId = [Guid]::NewGuid().ToString()
$appRoleId = [Guid]::NewGuid().ToString()
$appName = "CA-AuthCtx-WebApp"
$apiName = "CA-AuthCtx-WebApi"
$apiBaseUrl = "https://localhost:5001"

Write-Host "Creating API..." -ForegroundColor Cyan

$oauth2PermissionScopes = @(
    @{
        Id = $apiScopeId
        AdminConsentDescription = "Allows the application to access resources as the signed-in user."
        AdminConsentDisplayName = "Access as user"
        UserConsentDescription  = "Allows the application to access resources on your behalf."
        UserConsentDisplayName  = "Access as user"
        Value                   = "access_as_user"
        Type                    = "User"
        IsEnabled               = $true
    }
)

$appRoles = @(
    @{
        Id = $appRoleId
        AllowedMemberTypes = @("Application") # Specifies daemon/service apps can use this
        Description        = "Allows daemon applications to read API resources."
        DisplayName        = "Api.Read"
        Value              = "Api.Read"
        IsEnabled          = $true
    }
)

$apiAppParams = @{
    DisplayName = $apiName
    SignInAudience = "AzureADMyOrg" # Single Tenant
    Api = @{
        Oauth2PermissionScopes = $oauth2PermissionScopes
    }
    AppRoles = $appRoles
}

$webApiApp = New-MgApplication @apiAppParams

$apiUri = "api://$($webApiApp.AppId)"
Update-MgApplication -ApplicationId $webApiApp.Id -IdentifierUris @($apiUri)

$apiServicePrincipal = New-MgServicePrincipal -AppId $webApiApp.AppId

Write-Host "Creating App..." -ForegroundColor Cyan

$webAppParams = @{
    DisplayName = $appName
    SignInAudience = "AzureADMyOrg"
    Web = @{
        RedirectUris = @("$apiBaseUrl/signin-oidc")
        ImplicitGrantSettings = @{
            EnableIdTokenIssuance = $true
        }
    }
}

$webApp = New-MgApplication @webAppParams

$appServicePrincipal = New-MgServicePrincipal -AppId $webApp.AppId

$expiryDate = (Get-Date).AddMonths(12)

Write-Host "Generating client secret for API..." -ForegroundColor Cyan

$apiSecretParams = @{
    ApplicationId = $webApiApp.Id # The Object ID of the API app
    PasswordCredential = @{
        DisplayName = "API_Secret_set_by_ps"
        EndDateTime = $expiryDate
    }
}

$webApiSecret = Add-MgApplicationPassword @apiSecretParams

Write-Host "Generating client secret for App..." -ForegroundColor Cyan

$webAppSecretParams = @{
    ApplicationId = $webApp.Id # The Object ID of the client web app
    PasswordCredential = @{
        DisplayName = "App_Secret_set_by_ps"
        EndDateTime = $expiryDate
    }
}
$webAppSecret = Add-MgApplicationPassword @webAppSecretParams

Write-Host "Adding API permissions to App..." -ForegroundColor Cyan

$requiredGrantsList = New-Object -TypeName System.Collections.Generic.List[Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess]

$apiResourceAccess = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
$apiResourceAccess.ResourceAppId = $webApiApp.AppId  

$apiResourceAccess.ResourceAccess += @{
    Id   = $apiScopeId  
    Type = "Scope"
}
$apiResourceAccess.ResourceAccess += @{
    Id   = $appRoleId  
    Type = "Role"
}
$requiredGrantsList.Add($apiResourceAccess)

Update-MgApplication -ApplicationId $webApp.Id -RequiredResourceAccess $requiredGrantsList

$currentContext = Get-MgContext
$currentUserId = $currentContext.Account
$domain = (Get-MgContext).Account.Split('@')[1]
# If Account yields an email, fetch the absolute Object ID instead
if ($currentUserId -like "*@*") {
    $currentUserProfile = Invoke-MgGraphRequest -Method GET -Uri "v1.0/me"
    $currentUserId = $currentUserProfile.id
}

$ownerPayload = @{
    "@odata.id" = "https://graph.microsoft.com/v1.0/users/$currentUserId"
}

Write-Host "Assigning user $($currentContext.Account) as owner..." -ForegroundColor Cyan

New-MgApplicationOwnerByRef -ApplicationId $webApiApp.Id -BodyParameter $ownerPayload -ErrorAction Stop
New-MgApplicationOwnerByRef -ApplicationId $webApp.Id -BodyParameter $ownerPayload -ErrorAction Stop

####
<#
Write-Host "Tenant ID     : $tenantId`n"
Write-Host "API Client ID : $($webApiApp.AppId)"
Write-Host "API Secret    : $($webApiSecret.SecretText)"
Write-Host "API App ID URI: $apiUri`n"

Write-Host "App Client ID : $($webApp.AppId)"
Write-Host "App Secret    : $($webAppSecret.SecretText)"
Write-Host "Api Base Url  : $apiBaseUrl"
Write-Host "scopes        : $apiUri/$($oauth2PermissionScopes.Value)"
#>
$appsettings = (Get-Content "../AuthContextWebApp/appsettings.json" | ConvertFrom-json)
$appsettings.Entra.TenantId = $tenantId
$appsettings.Entra.Domain = $domain
$appsettings.Entra.ClientId = $webApp.AppId
$appsettings.Entra.ClientSecret = $webAppSecret.SecretText
$appsettings.DownstreamAPI.Scopes[0] = "$apiUri/$($oauth2PermissionScopes.Value)"

write-host "WebApp appsettings.json details:`n"
$appsettings | ConvertTo-json

$appsettings = (Get-Content "../AuthContextWebApi/appsettings.json" | ConvertFrom-json)
$appsettings.Entra.TenantId = $tenantId
$appsettings.Entra.Domain = $domain
$appsettings.Entra.ClientId = $webApiApp.AppId
$appsettings.Entra.ClientSecret = $webApiSecret.SecretText
$appsettings.Entra.Audience = "api://$($webApiApp.AppId)"

write-host "`nWebApi appsettings.json details:`n"
$appsettings | ConvertTo-json

Write-Host "*** REMEMBER TO 1) Grant Permission for $appName in Entra Portal, 2) Update AuthContext cNN value in both appsetting.json files ***" -ForegroundColor White