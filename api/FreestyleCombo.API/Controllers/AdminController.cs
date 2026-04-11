using FreestyleCombo.API.Features.Admin;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FreestyleCombo.API.Controllers;

[ApiController]
[Route("api/admin")]
[Authorize(Roles = "Admin")]
public class AdminController(IMediator mediator) : ControllerBase
{
    [HttpGet("pending-count")]
    public async Task<IActionResult> GetPendingCount(CancellationToken ct)
    {
        var count = await mediator.Send(new GetPendingApprovalsCountQuery(), ct);
        return Ok(new { total = count });
    }
}
