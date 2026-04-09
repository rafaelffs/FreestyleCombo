using FreestyleCombo.API.Features.Tricks.CreateTrick;
using FreestyleCombo.API.Features.Tricks.GetTricks;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FreestyleCombo.API.Controllers;

[ApiController]
[Route("api/tricks")]
public class TricksController : ControllerBase
{
    private readonly IMediator _mediator;

    public TricksController(IMediator mediator) => _mediator = mediator;

    [HttpGet]
    [ProducesResponseType(typeof(List<TrickDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetTricks([FromQuery] bool? crossOver, [FromQuery] bool? knee, [FromQuery] int? maxDifficulty, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetTricksQuery(crossOver, knee, maxDifficulty), ct);
        return Ok(result);
    }

    [HttpPost]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    public async Task<IActionResult> CreateTrick([FromBody] CreateTrickCommand command, CancellationToken ct)
    {
        var id = await _mediator.Send(command, ct);
        return CreatedAtAction(nameof(GetTricks), new { id }, new { id });
    }
}
