using System.Security.Claims;
using FreestyleCombo.API.Features.Preferences.GetPreferences;
using FreestyleCombo.API.Features.Preferences.UpdatePreferences;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FreestyleCombo.API.Controllers;

[ApiController]
[Route("api/preferences")]
[Authorize]
public class PreferencesController : ControllerBase
{
    private readonly IMediator _mediator;

    public PreferencesController(IMediator mediator) => _mediator = mediator;

    [HttpGet]
    [ProducesResponseType(typeof(PreferenceDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var result = await _mediator.Send(new GetPreferencesQuery(userId), ct);
        return Ok(result);
    }

    [HttpPut]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> Update([FromBody] UpdatePreferencesRequest request, CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        await _mediator.Send(new UpdatePreferencesCommand(
            userId,
            request.MaxDifficulty,
            request.ComboLength,
            request.StrongFootPercentage,
            request.NoTouchPercentage,
            request.MaxConsecutiveNoTouch,
            request.IncludeCrossOver,
            request.IncludeKnee,
            request.AllowedRevolutions
        ), ct);
        var result = await _mediator.Send(new GetPreferencesQuery(userId), ct);
        return Ok(result);
    }
}

public class UpdatePreferencesRequest
{
    public int? MaxDifficulty { get; set; }
    public int? ComboLength { get; set; }
    public int? StrongFootPercentage { get; set; }
    public int? NoTouchPercentage { get; set; }
    public int? MaxConsecutiveNoTouch { get; set; }
    public bool? IncludeCrossOver { get; set; }
    public bool? IncludeKnee { get; set; }
    public List<decimal>? AllowedRevolutions { get; set; }
}
