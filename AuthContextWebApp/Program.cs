using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Mvc.Authorization;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.UI;

namespace AuthContextWebApp; 
public class Program {
    public static void Main(string[] args) {
        var builder = WebApplication.CreateBuilder(args);

        builder.Services.Configure<ForwardedHeadersOptions>(options => {
            options.ForwardedHeaders =
                ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto | ForwardedHeaders.XForwardedHost;
        });

        builder.Services.AddAuthentication(OpenIdConnectDefaults.AuthenticationScheme)
            .AddMicrosoftIdentityWebApp(builder.Configuration.GetSection("Entra"))
            .EnableTokenAcquisitionToCallDownstreamApi()
            .AddDownstreamApi("DownstreamAPI", builder.Configuration.GetSection("DownstreamAPI"))
            .AddInMemoryTokenCaches();

        builder.Services.AddAuthorization(options => {
            options.FallbackPolicy = options.DefaultPolicy;
        });
        builder.Services.AddRazorPages()
            .AddMicrosoftIdentityUI();

        var app = builder.Build();

        if (!app.Environment.IsDevelopment()) {
            app.UseExceptionHandler("/Error");
            // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
            app.UseHsts();
        }

        app.UseHttpsRedirection();
        app.UseRouting();
        app.UseAuthorization();
        app.MapStaticAssets();
        app.MapRazorPages()
           .WithStaticAssets();
        app.MapControllers();

        app.Run();
    }
}
