using System.Security.Claims;
using FreestyleCombo.API.Features.Combos.AddFavourite;
using FreestyleCombo.API.Features.Combos.ApproveComboVisibility;
using FreestyleCombo.API.Features.Combos.BuildCombo;
using FreestyleCombo.API.Features.Combos.DeleteCombo;
using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.API.Features.Combos.GetCombo;
using FreestyleCombo.API.Features.Combos.GetMyCombos;
using FreestyleCombo.API.Features.Combos.GetPendingComboReviews;
using FreestyleCombo.API.Features.Combos.GetPublicCombos;
using FreestyleCombo.API.Features.Combos.PreviewCombo;
using FreestyleCombo.API.Features.Combos.RejectComboVisibility;
using FreestyleCombo.API.Features.Combos.RemoveFavourite;
using FreestyleCombo.API.Features.Combos.UpdateCombo;
using FreestyleCombo.API.Features.Combos.UpdateVisibility;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FreestyleCombo.API.Controllers;

[ApiController]
[Route("api/combos")]
public class CombosController : ControllerBase
{
    private readonly IMediator _mediator;

    public CombosController(IMediator mediator) => _mediator = mediator;

    [HttpPost("generate")]
    [Authorize]
    [ProducesResponseType(typeof(GenerateComboResponse), StatusCodes.Status201Created)]
    public async Task<IActionResult> Generate([FromBody] GenerateComboCommand command, CancellationToken ct)
    {
        var result = await _mediator.Send(command, ct);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    [HttpPost("preview")]
    [Authorize]
    [ProducesResponseType(typeof(PreviewComboResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> Preview([FromBody] PreviewComboCommand command, CancellationToken ct)
    {
        var result = await _mediator.Send(command, ct);
        return Ok(result);
    }

    [HttpPost("build")]
    [Authorize]
    [ProducesResponseType(typeof(GenerateComboResponse), StatusCodes.Status201Created)]
    public async Task<IActionResult> Build([FromBody] BuildComboCommand command, CancellationToken ct)
    {
        var result = await _mediator.Send(command, ct);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    [HttpGet("public")]
    [ProducesResponseType(typeof(PagedResult<PublicComboDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPublic(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string? sortBy = null,
        [FromQuery] int? maxDifficulty = null,
        CancellationToken ct = default)
    {
        Guid? requestingUserId = User.Identity?.IsAuthenticated == true
            ? Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!)
            : null;
        var result = await _mediator.Send(new GetPublicCombosQuery(page, pageSize, sortBy, maxDifficulty, requestingUserId), ct);
        return Ok(result);
    }

    [HttpGet("mine")]
    [Authorize]
    [ProducesResponseType(typeof(PagedResult<MyComboDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetMine(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] bool? isPublic = null,
        CancellationToken ct = default)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var result = await _mediator.Send(new GetMyCombosQuery(userId, page, pageSize, isPublic), ct);
        return Ok(result);
    }

    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(ComboDetailDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetById(Guid id, CancellationToken ct)
    {
        Guid? userId = User.Identity?.IsAuthenticated == true
            ? Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!)
            : null;

        var result = await _mediator.Send(new GetComboQuery(id, userId), ct);
        return Ok(result);
    }

    [HttpPut("{id:guid}")]
    [Authorize]
    [ProducesResponseType(typeof(GenerateComboResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateComboRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new UpdateComboCommand(id, request.Name, request.Tricks), ct);
        return Ok(result);
    }

    [HttpPut("{id:guid}/visibility")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateVisibility(Guid id, [FromBody] UpdateVisibilityRequest request, CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        await _mediator.Send(new UpdateVisibilityCommand(id, userId, request.IsPublic), ct);
        return Ok();
    }

    [HttpDelete("{id:guid}")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new DeleteComboCommand(id), ct);
        return NoContent();
    }

    [HttpGet("pending-review")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(typeof(List<PublicComboDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPendingReview(CancellationToken ct)
    {
        var result = await _mediator.Send(new GetPendingComboReviewsQuery(), ct);
        return Ok(result);
    }

    [HttpPost("{id:guid}/approve-visibility")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> ApproveVisibility(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new ApproveComboVisibilityCommand(id), ct);
        return Ok();
    }

    [HttpPost("{id:guid}/reject-visibility")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> RejectVisibility(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new RejectComboVisibilityCommand(id), ct);
        return Ok();
    }

    [HttpPost("{id:guid}/favourite")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> AddFavourite(Guid id, CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        await _mediator.Send(new AddFavouriteCommand(id, userId), ct);
        return Ok();
    }

    [HttpDelete("{id:guid}/favourite")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> RemoveFavourite(Guid id, CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        await _mediator.Send(new RemoveFavouriteCommand(id, userId), ct);
        return Ok();
    }
}

public record UpdateVisibilityRequest(bool IsPublic);
public record UpdateComboRequest(string? Name, List<BuildComboTrickItem>? Tricks);
