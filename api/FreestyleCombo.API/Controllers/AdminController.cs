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

    // User management

    [HttpGet("users")]
    [ProducesResponseType(typeof(List<AdminUserDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetUsers(CancellationToken ct)
    {
        var result = await mediator.Send(new GetUsersQuery(), ct);
        return Ok(result);
    }

    [HttpPut("users/{id:guid}")]
    [ProducesResponseType(typeof(AdminUserDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateUser(Guid id, [FromBody] UpdateUserCommand command, CancellationToken ct)
    {
        var result = await mediator.Send(command with { UserId = id }, ct);
        return Ok(result);
    }

    [HttpPut("users/{id:guid}/password")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> ResetUserPassword(Guid id, [FromBody] ResetUserPasswordCommand command, CancellationToken ct)
    {
        await mediator.Send(command with { UserId = id }, ct);
        return NoContent();
    }

    [HttpPut("users/{id:guid}/role")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> UpdateUserRole(Guid id, [FromBody] UpdateUserRoleCommand command, CancellationToken ct)
    {
        await mediator.Send(command with { UserId = id }, ct);
        return NoContent();
    }

    [HttpDelete("users/{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> DeleteUser(Guid id, CancellationToken ct)
    {
        await mediator.Send(new DeleteUserCommand(id), ct);
        return NoContent();
    }
}
