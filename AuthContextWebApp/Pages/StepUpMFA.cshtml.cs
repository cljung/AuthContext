using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using System.Text.Json;

namespace AuthContextWebApp.Pages; 
public class StepUpMFAModel : PageModel {
    protected readonly IConfiguration _configuration;
    private string requiredAuthContextId = "c13";
    public StepUpMFAModel(IConfiguration configuration) {
        _configuration = configuration;
        requiredAuthContextId = _configuration.GetValue("AuthContextId", requiredAuthContextId);
    }
    public async Task OnGet() {
        bool hasAuthContext = User.FindFirst("acrs")?.Value == requiredAuthContextId;
        if ( !hasAuthContext ) {
            var claimsChallenge = new {
                id_token = new {
                    acrs = new {
                        essential = true,
                        value = requiredAuthContextId
                    }
                }
            };
            var properties = new AuthenticationProperties();
            properties.Items.Add("claims", JsonSerializer.Serialize(claimsChallenge));
            await HttpContext.ChallengeAsync(OpenIdConnectDefaults.AuthenticationScheme, properties);
        }
    }
}
