using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Identity.Web;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace AuthContextWebApi.Controllers;

[ApiController]
public class ApiController : ControllerBase {

    protected readonly ILogger<ApiController> _log;
    protected readonly IConfiguration _configuration;
    private static readonly JsonSerializerOptions CompactJsonOptions = new() {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };
    private string requiredAuthContextId = "c13";

    public ApiController(IConfiguration configuration, ILogger<ApiController> log) {
        _configuration = configuration;
        _log = log;
        requiredAuthContextId = _configuration.GetValue("AuthContextId", requiredAuthContextId);
    }
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    // Helpers
    /////////////////////////////////////////////////////////////////////////////////////////////////////

    protected string GetClientIpAddr() {
        string ipaddr = "";
        string? xForwardedFor = this.Request.Headers["X-Forwarded-For"];
        if (!string.IsNullOrEmpty(xForwardedFor))
             ipaddr = xForwardedFor;
        else ipaddr = this.Request.HttpContext.Connection.RemoteIpAddress!.ToString() ?? string.Empty;
        return ipaddr;
    }

    protected void TraceHttpRequest() {
        StringBuilder sb = new StringBuilder();
        foreach (var header in this.Request.Headers) {
            sb.AppendFormat(System.Globalization.CultureInfo.InvariantCulture, "      {0}: {1}\n", header.Key, header.Value);
        }
        _log.LogTrace("{Timestamp} {IpAddr}\n      {Method} {Scheme}://{Host}{Path}{QueryString}\n{Headers}"
                , DateTime.UtcNow.ToString("o", System.Globalization.CultureInfo.InvariantCulture)
                , GetClientIpAddr()
                , this.Request.Method, this.Request.Scheme, this.Request.Host, this.Request.Path
                , this.Request.QueryString, sb.ToString());
    }

    protected bool IsUserToken() {
        if (HttpContext!.User == null) return false;
        var scopeClaim = HttpContext.User.FindFirst(c => c.Type == ClaimConstants.Scope || c.Type == ClaimConstants.Scp);
        if (scopeClaim == null) return false;
        return true;
    }
    protected bool HasRequiredAuthContext() {
        return User.FindFirst("acrs")?.Value == requiredAuthContextId;
    }

    protected UnauthorizedObjectResult ReturnUnauthorizedAuthContext() {
        var claimsChallenge = new {
            access_token = new {
                acrs = new {
                    essential = true,
                    value = requiredAuthContextId
                }
            }
        };
        string base64Challenge = Convert.ToBase64String(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(claimsChallenge)));
        _log.LogTrace($"[401] WWW-Authenticate: Bearer error=\"insufficient_claims\", claims=\"{base64Challenge}\"");
        Response.Headers.Append("WWW-Authenticate", $"Bearer error=\"insufficient_claims\", claims=\"{base64Challenge}\"");
        return Unauthorized("Step-up authentication is required for this action.");
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////
    // API Endpoints
    /////////////////////////////////////////////////////////////////////////////////////////////////////

    [HttpGet("/api/sensitiveoperation")]
    [Authorize(Policy = "ScopeOrRolePolicy.Read")]
    [Produces("application/json")]
    public async Task<ActionResult<string>> Get() {
        TraceHttpRequest();

        // Only require the acr 'c13' claim if it is a user calling the API.
        // Service principals will never pass that.
        if ( IsUserToken() && !HasRequiredAuthContext() ) {
            return ReturnUnauthorizedAuthContext();
        }

        var resp = new { Message = "Sensitive operation completed successfully.", Timestamp = DateTime.UtcNow.ToString("o") };
        string content = JsonSerializer.Serialize(resp, CompactJsonOptions);
        _log.LogTrace($"[200] {content}");
        return new ContentResult { ContentType = "application/json", Content = content, StatusCode = (int)HttpStatusCode.OK };
    }
}
