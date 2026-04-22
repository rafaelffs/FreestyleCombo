using System.Security.Claims;
using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Combos.BuildCombo;

public class BuildComboHandler : IRequestHandler<BuildComboCommand, GenerateComboResponse>
{
    private readonly ITrickRepository _trickRepo;
    private readonly IComboRepository _comboRepo;
    private readonly IHttpContextAccessor _http;
    private readonly UserManager<AppUser> _userManager;

    public BuildComboHandler(ITrickRepository trickRepo, IComboRepository comboRepo, IHttpContextAccessor http, UserManager<AppUser> userManager)
    {
        _trickRepo = trickRepo;
        _comboRepo = comboRepo;
        _http = http;
        _userManager = userManager;
    }

    public async Task<GenerateComboResponse> Handle(BuildComboCommand request, CancellationToken cancellationToken)
    {
        var userId = Guid.Parse(_http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var isAdmin = _http.HttpContext.User.IsInRole("Admin");
        var user = await _userManager.FindByIdAsync(userId.ToString());

        // Load all referenced tricks
        var trickIds = request.Tricks.Select(t => t.TrickId).Distinct().ToList();
        var allTricks = await _trickRepo.GetAllAsync(ct: cancellationToken);
        var trickMap = allTricks.Where(t => trickIds.Contains(t.Id)).ToDictionary(t => t.Id);

        // Validate all tricks exist
        var missing = trickIds.Except(trickMap.Keys).ToList();
        if (missing.Count > 0)
            throw new KeyNotFoundException($"Trick(s) not found: {string.Join(", ", missing)}");

        // Strip NoTouch from non-CrossOver tricks (silently, consistent with UpdateComboHandler)
        var normalized = request.Tricks
            .Select(t => t with { NoTouch = t.NoTouch && trickMap[t.TrickId].CrossOver })
            .ToList();

        // Order by position
        var ordered = normalized.OrderBy(t => t.Position).ToList();

        var avgDifficulty = Math.Round(ordered.Average(t => (double)trickMap[t.TrickId].Difficulty), 1);

        var displayText = string.Join(" ", ordered.Select(t =>
        {
            var trick = trickMap[t.TrickId];
            return t.NoTouch ? $"{trick.Abbreviation}(nt)" : trick.Abbreviation;
        }));

        var combo = new Combo
        {
            Id = Guid.NewGuid(),
            OwnerId = userId,
            Name = string.IsNullOrWhiteSpace(request.Name) ? null : request.Name.Trim(),
            AverageDifficulty = avgDifficulty,
            TrickCount = ordered.Count,
            Visibility = request.IsPublic
                ? (isAdmin ? ComboVisibility.Public : ComboVisibility.PendingReview)
                : ComboVisibility.Private,
            CreatedAt = DateTime.UtcNow,
            AiDescription = null,
            ComboTricks = ordered.Select(t => new ComboTrick
            {
                Id = Guid.NewGuid(),
                TrickId = t.TrickId,
                Position = t.Position,
                StrongFoot = t.StrongFoot,
                NoTouch = t.NoTouch
            }).ToList()
        };

        await _comboRepo.AddAsync(combo, cancellationToken);

        return new GenerateComboResponse
        {
            Id = combo.Id,
            OwnerId = combo.OwnerId,
            OwnerUserName = user?.UserName,
            Name = combo.Name,
            AverageDifficulty = combo.AverageDifficulty,
            TrickCount = combo.TrickCount,
            IsPublic = combo.IsPublic,
            Visibility = combo.Visibility.ToString(),
            CreatedAt = combo.CreatedAt,
            DisplayText = displayText,
            AiDescription = null,
            Warnings = [],
            Tricks = ordered.Select(t =>
            {
                var trick = trickMap[t.TrickId];
                return new ComboTrickDto
                {
                    TrickId = trick.Id,
                    Name = trick.Name,
                    Abbreviation = trick.Abbreviation,
                    Position = t.Position,
                    StrongFoot = t.StrongFoot,
                    NoTouch = t.NoTouch,
                    Difficulty = trick.Difficulty,
                    Revolution = trick.Revolution,
                    CrossOver = trick.CrossOver,
                    IsTransition = trick.IsTransition
                };
            }).ToList()
        };
    }
}
