using FreestyleCombo.API.Features.TrickSubmissions;
using FreestyleCombo.API.Features.TrickSubmissions.ApproveSubmission;
using FreestyleCombo.API.Features.TrickSubmissions.GetMySubmissions;
using FreestyleCombo.API.Features.TrickSubmissions.GetPendingSubmissions;
using FreestyleCombo.API.Features.TrickSubmissions.RejectSubmission;
using FreestyleCombo.API.Features.TrickSubmissions.SubmitTrick;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FreestyleCombo.API.Controllers;

[ApiController]
[Route("api/trick-submissions")]
[Authorize]
public class TrickSubmissionsController : ControllerBase
{
    private readonly IMediator _mediator;

    public TrickSubmissionsController(IMediator mediator) => _mediator = mediator;

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    public async Task<IActionResult> Submit([FromBody] SubmitTrickCommand command, CancellationToken ct)
    {
        var id = await _mediator.Send(command, ct);
        return Created($"api/trick-submissions/{id}", new { id });
    }

    [HttpGet("mine")]
    [ProducesResponseType(typeof(List<TrickSubmissionDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetMine(CancellationToken ct)
    {
        var result = await _mediator.Send(new GetMySubmissionsQuery(), ct);
        return Ok(result);
    }

    [HttpGet("pending")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(typeof(List<TrickSubmissionDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPending(CancellationToken ct)
    {
        var result = await _mediator.Send(new GetPendingSubmissionsQuery(), ct);
        return Ok(result);
    }

    [HttpPost("{id:guid}/approve")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Approve(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new ApproveSubmissionCommand(id), ct);
        return NoContent();
    }

    [HttpPost("{id:guid}/reject")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Reject(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new RejectSubmissionCommand(id), ct);
        return NoContent();
    }
}
