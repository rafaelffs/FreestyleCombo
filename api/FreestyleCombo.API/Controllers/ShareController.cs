using FreestyleCombo.Core.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace FreestyleCombo.API.Controllers;

[ApiController]
[Route("share")]
public class ShareController : ControllerBase
{
    private readonly IComboRepository _repo;

    public ShareController(IComboRepository repo)
    {
        _repo = repo;
    }

    [HttpGet("combos/{id:guid}")]
    public async Task<IActionResult> ShareCombo(Guid id, CancellationToken ct)
    {
        var combo = await _repo.GetByIdAsync(id, ct);

        // Only publicly visible combos are shareable
        if (combo is null || combo.Visibility != Core.Entities.ComboVisibility.Public)
            return Redirect("/combos");

        var appOrigin = $"{Request.Scheme}://{Request.Host}";

        var title = combo.Name is { Length: > 0 }
            ? combo.Name
            : string.Join(" → ", combo.ComboTricks
                .OrderBy(ct2 => ct2.Position)
                .Select(ct2 => ct2.Trick.Abbreviation));

        var trickCount = combo.TrickCount;
        var avgDiff = combo.AverageDifficulty.ToString("F1");
        var owner = combo.Owner?.UserName ?? "anonymous";
        var description = $"{trickCount} tricks · avg difficulty {avgDiff} · by {owner}";

        var spaUrl = $"{appOrigin}/combos/{id}";
        var imageUrl = $"{appOrigin}/og-image.png";

        var html = $"""
            <!DOCTYPE html>
            <html lang="en">
            <head>
              <meta charset="utf-8" />
              <title>{Encode(title)} — FreestyleCombo</title>

              <!-- Open Graph -->
              <meta property="og:type" content="website" />
              <meta property="og:site_name" content="FreestyleCombo" />
              <meta property="og:title" content="{Encode(title)}" />
              <meta property="og:description" content="{Encode(description)}" />
              <meta property="og:url" content="{spaUrl}" />
              <meta property="og:image" content="{imageUrl}" />
              <meta property="og:image:width" content="1200" />
              <meta property="og:image:height" content="630" />

              <!-- Twitter / X -->
              <meta name="twitter:card" content="summary_large_image" />
              <meta name="twitter:title" content="{Encode(title)}" />
              <meta name="twitter:description" content="{Encode(description)}" />
              <meta name="twitter:image" content="{imageUrl}" />

              <!-- Redirect real users to the SPA immediately -->
              <meta http-equiv="refresh" content="0; url={spaUrl}" />
            </head>
            <body>
              <p>Redirecting… <a href="{spaUrl}">click here</a> if nothing happens.</p>
              <script>window.location.replace("{spaUrl}");</script>
            </body>
            </html>
            """;

        return Content(html, "text/html");
    }

    private static string Encode(string s) =>
        System.Net.WebUtility.HtmlEncode(s);
}
