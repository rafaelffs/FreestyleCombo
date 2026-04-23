using FreestyleCombo.API.Features.Tricks.CreateTrick;
using FreestyleCombo.API.Features.Tricks.DeleteTrick;
using FreestyleCombo.API.Features.Tricks.GetTricks;
using FreestyleCombo.API.Features.Tricks.UpdateTrick;
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
    public async Task<IActionResult> GetTricks(
        [FromQuery] bool? crossOver,
        [FromQuery] bool? knee,
        [FromQuery] int? maxDifficulty,
        CancellationToken ct)
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

    [HttpPut("{id:guid}")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> UpdateTrick(Guid id, [FromBody] UpdateTrickRequest request, CancellationToken ct)
    {
        await _mediator.Send(new UpdateTrickCommand(
            id,
            request.Name,
            request.Abbreviation,
            request.CrossOver,
            request.Knee,
            request.Revolution,
            request.Difficulty,
            request.CommonLevel,
            request.CreatedBy,
            request.DateCreated,
            request.Notes), ct);
        return NoContent();
    }

    [HttpDelete("{id:guid}")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> DeleteTrick(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new DeleteTrickCommand(id), ct);
        return NoContent();
    }
}

public record UpdateTrickRequest(
    string Name,
    string Abbreviation,
    bool CrossOver,
    bool Knee,
    decimal Revolution,
    int Difficulty,
    int CommonLevel,
    string? CreatedBy,
    DateOnly? DateCreated,
    string? Notes);
