using FreestyleCombo.Core.Entities;
using FreestyleCombo.Infrastructure.Data;
using MediatR;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace FreestyleCombo.API.Features.Admin;

public record GetUsersQuery : IRequest<List<AdminUserDto>>;

public record AdminUserDto(Guid Id, string UserName, string Email, bool IsAdmin, int ComboCount);

public class GetUsersHandler : IRequestHandler<GetUsersQuery, List<AdminUserDto>>
{
    private readonly UserManager<AppUser> _userManager;
    private readonly AppDbContext _db;

    public GetUsersHandler(UserManager<AppUser> userManager, AppDbContext db)
    {
        _userManager = userManager;
        _db = db;
    }

    public async Task<List<AdminUserDto>> Handle(GetUsersQuery request, CancellationToken cancellationToken)
    {
        var users = await _userManager.Users.ToListAsync(cancellationToken);

        var comboCounts = await _db.Combos
            .GroupBy(c => c.OwnerId)
            .Select(g => new { OwnerId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.OwnerId, x => x.Count, cancellationToken);

        var result = new List<AdminUserDto>();
        foreach (var user in users.OrderBy(u => u.UserName))
        {
            var roles = await _userManager.GetRolesAsync(user);
            comboCounts.TryGetValue(user.Id, out var comboCount);
            result.Add(new AdminUserDto(user.Id, user.UserName!, user.Email!, roles.Contains("Admin"), comboCount));
        }

        return result;
    }
}
