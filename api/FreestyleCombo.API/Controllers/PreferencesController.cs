using System.Security.Claims;
using FreestyleCombo.API.Features.Preferences.CreatePreference;
using FreestyleCombo.API.Features.Preferences.DeletePreference;
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
    [ProducesResponseType(typeof(List<PreferenceDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAll(CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var result = await _mediator.Send(new GetPreferencesQuery(userId), ct);
        return Ok(result);
    }

    [HttpPost]
    [ProducesResponseType(typeof(PreferenceDto), StatusCodes.Status201Created)]
    public async Task<IActionResult> Create([FromBody] PreferenceRequest request, CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var result = await _mediator.Send(new CreatePreferenceCommand(
            userId,
            request.Name ?? string.Empty,
            request.MaxDifficulty,
            request.ComboLength,
            request.StrongFootPercentage,
            request.NoTouchPercentage,
            request.MaxConsecutiveNoTouch,
            request.IncludeCrossOver,
            request.IncludeKnee,
            request.AllowedRevolutions
        ), ct);
        return CreatedAtAction(nameof(GetAll), result);
    }

    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(PreferenceDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> Update(Guid id, [FromBody] PreferenceRequest request, CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var result = await _mediator.Send(new UpdatePreferencesCommand(
            id,
            userId,
            request.Name ?? string.Empty,
            request.MaxDifficulty,
            request.ComboLength,
            request.StrongFootPercentage,
            request.NoTouchPercentage,
            request.MaxConsecutiveNoTouch,
            request.IncludeCrossOver,
            request.IncludeKnee,
            request.AllowedRevolutions
        ), ct);
        return Ok(result);
    }

    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        await _mediator.Send(new DeletePreferenceCommand(id, userId), ct);
        return NoContent();
    }
}

public class PreferenceRequest
{
    public string? Name { get; set; }
    public int MaxDifficulty { get; set; } = 10;
    public int ComboLength { get; set; } = 6;
    public int StrongFootPercentage { get; set; } = 60;
    public int NoTouchPercentage { get; set; } = 30;
    public int MaxConsecutiveNoTouch { get; set; } = 2;
    public bool IncludeCrossOver { get; set; } = true;
    public bool IncludeKnee { get; set; } = true;
    public List<decimal> AllowedRevolutions { get; set; } = [];
}
