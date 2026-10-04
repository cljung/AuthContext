# Entra Authentication Context sample

Entra AuthContext step-up MFA sample

There is a [blog post](https://blog.redbaronofazure.com/?p=8086) explaining Entra Authentication Context in detail that this sample code belongs to.

## Configuration via Powershell

There are powershell configuration scripts in the [scripts](scripts) folder. Run them in the following order.

| Step | Script | Details |
|------|--------|--------|
| 1. | [Connect-to-MgGrapoh.ps1](scripts/Connect-to-MgGrapoh.ps1) | Imports the Graph modules and logs in |
| 2. | [Create-AuthContext-and-CA-Policy.ps1](scripts/Create-AuthContext-and-CA-Policy.ps1) | Creates the Authentication Context object and a Conditional Access policy targetin it. |
| 3. | [Create-AuthContext-App-and-Api.ps1](scripts/Create-AuthContext-App-and-Api.ps1) | Creates the WebApp and the WebApi Entra app registrations. 
It outputs JSON at end that can be copied into the appsettings.json files |


Important things to notice:

- The Conditional Access policy is created with state `diabled`. Check that it meets your test scenario and enable it.
- After the app registration script, you must grant admin consent to the WebApp in the Entra portal.
- The `AuthContectId` value it both appsettings.json file needs to be updated to the value you got.

## Configuration manually in the Entra portal

### App registrations

1. Create an app registration for the **WebApi**. 
	1. In `Expose an API`¨, add a scope `access_as_user`
	1. In `App roles`, add a role `Api.Read`.
	1. Create a client secret
1. Create an app registration for the **WebApp** with Web Redirect Uri `https://localhost:5001/signin-oidc`
	1. In 'API Permissions', select `Add a permission` > My APIs > your WebApi > Delegated > access_as_user
	1. In 'API Permissions', select `Add a permission` > My APIs > your WebApi > Application > Api.Read
	1. Grant admin consent
	1. Create a client secret
1. Update both appsettings.json files with the details

### Authentication Context & Conditional Access policy

1. Goto `Conditional Access`
1. `Authentication context` > + New authentication context, create a new and remember the cNN value
1. `Policies` > 
	1. + New policy. Target dropdown, select Authentication context, then select your Auth Context
	1. Grant > Require MFA
	1. Users > Select your test user or test group

## Test run

### In Visual Studio

Start the WebApp and sign in, then Debug > Start New instance and start the WebApi

### Command Line

```Command
start dotnet run --project ./AuthContextWebApi/AuthContextWebApi.csproj -lp https

start dotnet run --project ./AuthContextWebApp/AuthContextWebApp.csproj -lp https

start https://localhost:5001
```

### Test steps

1. Sign in to the WebApp
1. Click `View Claims` to see that you have no `acrs` claim. If you do, sign out to clear session and sign in again.
1. Click `Call API` and see MFA being triggered

If you are troubleshooting the MFA CA policy, you can click `Step-Up MFA` in the `WebApp` to trigger it if the API isn't running.

To see that the Auth Context isn't enforce when it is an api-to-api call, you can start just the `WebApi` and run script [CallAPI-ClientCredentials.ps1](/scripts/CallAPI-ClientCredentials.ps1).
It will acquire an access token via client credentials an call the same API without being challanged.