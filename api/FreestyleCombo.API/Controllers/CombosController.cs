using System.Security.Claims;
using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.API.Features.Combos.GetCombo;
using FreestyleCombo.API.Features.Combos.GetMyCombos;
using FreestyleCombo.API.Features.Combos.GetPublicCombos;
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

    [HttpGet("public")]
    [ProducesResponseType(typeof(PagedResult<PublicComboDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPublic(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string? sortBy = null,
        [FromQuery] int? maxDifficulty = null,
        CancellationToken ct = default)
    {
        var result = await _mediator.Send(new GetPublicCombosQuery(page, pageSize, sortBy, maxDifficulty), ct);
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

    [HttpPut("{id:guid}/visibility")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateVisibility(Guid id, [FromBody] UpdateVisibilityRequest request, CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        await _mediator.Send(new UpdateVisibilityCommand(id, userId, request.IsPublic), ct);
        return Ok();
    }
}

public record UpdateVisibilityRequest(bool IsPublic);
