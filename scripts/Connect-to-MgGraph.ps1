Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Applications
Import-Module Microsoft.Graph.Identity.SignIns
Connect-MgGraph -Scopes "Application.ReadWrite.All", "Policy.ReadWrite.ConditionalAccess", "AuthenticationContext.ReadWrite.All"
