using System.Security.Claims;
using FreestyleCombo.API.Features.Ratings.GetRatings;
using FreestyleCombo.API.Features.Ratings.RateCombo;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FreestyleCombo.API.Controllers;

[ApiController]
[Route("api/combos/{comboId:guid}/ratings")]
public class RatingsController : ControllerBase
{
    private readonly IMediator _mediator;

    public RatingsController(IMediator mediator) => _mediator = mediator;

    [HttpPost]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status201Created)]
    public async Task<IActionResult> Rate(Guid comboId, [FromBody] RateRequest request, CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var id = await _mediator.Send(new RateComboCommand(comboId, userId, request.Score), ct);
        return StatusCode(StatusCodes.Status201Created, new { id });
    }

    [HttpGet]
    [ProducesResponseType(typeof(RatingsStatsDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetRatings(Guid comboId, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetRatingsQuery(comboId), ct);
        return Ok(result);
    }
}

public record RateRequest(int Score);
