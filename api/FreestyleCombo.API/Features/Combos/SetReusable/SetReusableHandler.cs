using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Combos.SetReusable;

public class SetReusableHandler : IRequestHandler<SetReusableCommand, GenerateComboResponse>
{
    private readonly IComboRepository _comboRepo;
    private readonly UserManager<AppUser> _userManager;

    public SetReusableHandler(IComboRepository comboRepo, UserManager<AppUser> userManager)
    {
        _comboRepo = comboRepo;
        _userManager = userManager;
    }

    public async Task<GenerateComboResponse> Handle(SetReusableCommand request, CancellationToken cancellationToken)
    {
        var combo = await _comboRepo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        if (request.IsReusable && combo.Visibility != ComboVisibility.Public)
            throw new InvalidOperationException("Only Public combos can be marked as reusable.");

        combo.IsReusable = request.IsReusable;
        await _comboRepo.UpdateAsync(combo, cancellationToken);

        var owner = await _userManager.FindByIdAsync(combo.OwnerId.ToString());

        var tricks = combo.ComboTricks
            .Where(ct => ct.TrickId.HasValue)
            .OrderBy(ct => ct.Position)
            .ToList();

        var displayText = string.Join(" ", tricks.Select(ct =>
            ct.NoTouch ? $"{ct.Trick!.Abbreviation}(nt)" : ct.Trick!.Abbreviation));

        return new GenerateComboResponse
        {
            Id = combo.Id,
            OwnerId = combo.OwnerId,
            OwnerUserName = owner?.UserName,
            Name = combo.Name,
            TotalDifficulty = combo.TotalDifficulty,
            TrickCount = combo.TrickCount,
            IsPublic = combo.IsPublic,
            IsReusable = combo.IsReusable,
            Visibility = combo.Visibility.ToString(),
            CreatedAt = combo.CreatedAt,
            DisplayText = displayText,
            AiDescription = combo.AiDescription,
            Warnings = [],
            Tricks = tricks.Select(ct => new ComboTrickDto
            {
                TrickId = ct.TrickId,
                Name = ct.Trick!.Name,
                Abbreviation = ct.Trick.Abbreviation,
                Position = ct.Position,
                StrongFoot = ct.StrongFoot,
                NoTouch = ct.NoTouch,
                Difficulty = ct.Trick.Difficulty,
                Revolution = ct.Trick.Revolution,
                CrossOver = ct.Trick.CrossOver,
                IsTransition = ct.Trick.IsTransition
            }).ToList()
        };
    }
}
