using System.Security.Claims;
using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Combos.UpdateCombo;

public class UpdateComboHandler : IRequestHandler<UpdateComboCommand, GenerateComboResponse>
{
    private readonly IComboRepository _comboRepo;
    private readonly ITrickRepository _trickRepo;
    private readonly IHttpContextAccessor _http;
    private readonly UserManager<AppUser> _userManager;

    public UpdateComboHandler(
        IComboRepository comboRepo,
        ITrickRepository trickRepo,
        IHttpContextAccessor http,
        UserManager<AppUser> userManager)
    {
        _comboRepo = comboRepo;
        _trickRepo = trickRepo;
        _http = http;
        _userManager = userManager;
    }

    public async Task<GenerateComboResponse> Handle(UpdateComboCommand request, CancellationToken cancellationToken)
    {
        var userId = Guid.Parse(_http.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var isAdmin = _http.HttpContext.User.IsInRole("Admin");

        var combo = await _comboRepo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        if (combo.OwnerId != userId && !isAdmin)
            throw new UnauthorizedAccessException("You do not have permission to edit this combo.");

        // Update name
        combo.Name = string.IsNullOrWhiteSpace(request.Name) ? null : request.Name.Trim();

        // Update tricks if provided
        if (request.Tricks is { Count: > 0 })
        {
            var trickIds = request.Tricks.Select(t => t.TrickId).Distinct().ToList();
            var allTricks = await _trickRepo.GetAllAsync(ct: cancellationToken);
            var trickMap = allTricks.Where(t => trickIds.Contains(t.Id)).ToDictionary(t => t.Id);

            var missing = trickIds.Except(trickMap.Keys).ToList();
            if (missing.Count > 0)
                throw new KeyNotFoundException($"Trick(s) not found: {string.Join(", ", missing)}");

            foreach (var item in request.Tricks)
            {
                if (item.NoTouch && !trickMap[item.TrickId].CrossOver)
                    throw new InvalidOperationException(
                        $"NoTouch can only be applied to CrossOver tricks. '{trickMap[item.TrickId].Name}' is not a CrossOver trick.");
            }

            var ordered = request.Tricks.OrderBy(t => t.Position).ToList();

            combo.ComboTricks.Clear();
            foreach (var t in ordered)
            {
                combo.ComboTricks.Add(new ComboTrick
                {
                    Id = Guid.NewGuid(),
                    ComboId = combo.Id,
                    TrickId = t.TrickId,
                    Position = t.Position,
                    StrongFoot = t.StrongFoot,
                    NoTouch = t.NoTouch,
                });
            }

            combo.TrickCount = ordered.Count;
            combo.AverageDifficulty = Math.Round(ordered.Average(t => (double)trickMap[t.TrickId].Difficulty), 1);
        }

        // If the combo was public, it must go back through admin review
        if (combo.Visibility == ComboVisibility.Public)
            combo.Visibility = ComboVisibility.PendingReview;

        await _comboRepo.UpdateAsync(combo, cancellationToken);

        var owner = await _userManager.FindByIdAsync(combo.OwnerId.ToString());
        var orderedTricks = combo.ComboTricks.OrderBy(t => t.Position).ToList();

        var displayText = string.Join(" ", orderedTricks.Select(ct =>
        {
            var trick = ct.Trick;
            return ct.NoTouch ? $"{trick.Abbreviation}(nt)" : trick.Abbreviation;
        }));

        return new GenerateComboResponse
        {
            Id = combo.Id,
            OwnerId = combo.OwnerId,
            OwnerUserName = owner?.UserName,
            Name = combo.Name,
            AverageDifficulty = combo.AverageDifficulty,
            TrickCount = combo.TrickCount,
            IsPublic = combo.IsPublic,
            Visibility = combo.Visibility.ToString(),
            CreatedAt = combo.CreatedAt,
            DisplayText = displayText,
            AiDescription = combo.AiDescription,
            Warnings = [],
            Tricks = orderedTricks.Select(ct =>
            {
                var trick = ct.Trick;
                return new ComboTrickDto
                {
                    TrickId = trick.Id,
                    Name = trick.Name,
                    Abbreviation = trick.Abbreviation,
                    Position = ct.Position,
                    StrongFoot = ct.StrongFoot,
                    NoTouch = ct.NoTouch,
                    Difficulty = trick.Difficulty,
                    Revolution = trick.Revolution
                };
            }).ToList()
        };
    }
}
