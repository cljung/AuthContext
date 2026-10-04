using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Identity.Abstractions;
using Microsoft.Identity.Web;
using System.Text.Json;

namespace AuthContextWebApp.Pages; 
public class CallAPIModel : PageModel {
    protected readonly IDownstreamApi _downstreamApi;    
    protected readonly ILogger<CallAPIModel> _log;
    public CallAPIModel( IDownstreamApi downstreamApi, ILogger<CallAPIModel> log ) {
        _downstreamApi = downstreamApi;
        _log = log;
    }
    private async Task HandleUserChallangeException(MicrosoftIdentityWebChallengeUserException miwcue ) {
        _log.LogError($"MicrosoftIdentityWebChallengeUserException: {miwcue.Message}");
        var properties = new AuthenticationProperties();
        /* 
         * AADSTS50076: Due to a configuration change made by your administrator, or because you moved to a new location, 
         * you must use multi-factor authentication to access '<api appId>'. 
         * The returned error contains a claims challenge. 
         * For additional info on how to handle claims related to multifactor authentication, Conditional Access, and incremental consent, 
         * see https://aka.ms/msal-conditional-access-claims. 
         * If you are using the On-Behalf-Of flow, see https://aka.ms/msal-conditional-access-claims-obo for details.
         * */
        if (   null != miwcue.MsalUiRequiredException 
            && miwcue.MsalUiRequiredException.Message.Contains("AADSTS50076:")
            && null != miwcue.MsalUiRequiredException.Claims ) {
            properties.Items.Add("claims", miwcue.MsalUiRequiredException.Claims);
        }
        await HttpContext.ChallengeAsync(OpenIdConnectDefaults.AuthenticationScheme, properties);
    }
    public async Task OnGet() {

        try {
            ApiResponseDTO resp = await _downstreamApi!.GetForUserAsync<ApiResponseDTO>("DownstreamAPI",
                options => { options.RelativePath = "api/sensitiveoperation"; });
            ViewData["InfoText"] = $"[{resp.Timestamp}] {resp.Message}";
        } catch (MicrosoftIdentityWebChallengeUserException miwcue) {
            await HandleUserChallangeException(miwcue);
        } catch (HttpRequestException hrex) {
            _log.LogError($"HttpRequestException: {hrex.Message}");
            ViewData["InfoText"] = $"The request returned an unexpected status: {hrex.Message}";
        } catch (Exception ex) {
            _log.LogError($"Exception: {ex.Message}");
            ViewData["InfoText"] = $"Internal error: {ex.Message}";
        }

    }
}

public class ApiResponseDTO {
    public string? Message { get; set; }
    public string? Timestamp { get; set; }
}
