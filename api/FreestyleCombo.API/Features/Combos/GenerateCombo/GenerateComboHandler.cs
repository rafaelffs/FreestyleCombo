using System.Security.Claims;
using FreestyleCombo.AI.Models;
using FreestyleCombo.AI.Services;
using FreestyleCombo.API.Features.Combos;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;

namespace FreestyleCombo.API.Features.Combos.GenerateCombo;

public class GenerateComboHandler : IRequestHandler<GenerateComboCommand, GenerateComboResponse>
{
    private readonly ITrickRepository _trickRepo;
    private readonly IComboRepository _comboRepo;
    private readonly IUserPreferenceRepository _prefRepo;
    private readonly IComboEnhancerService _enhancer;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly UserManager<AppUser> _userManager;

    public GenerateComboHandler(
        ITrickRepository trickRepo,
        IComboRepository comboRepo,
        IUserPreferenceRepository prefRepo,
        IComboEnhancerService enhancer,
        IHttpContextAccessor httpContextAccessor,
        UserManager<AppUser> userManager)
    {
        _trickRepo = trickRepo;
        _comboRepo = comboRepo;
        _prefRepo = prefRepo;
        _enhancer = enhancer;
        _httpContextAccessor = httpContextAccessor;
        _userManager = userManager;
    }

    public async Task<GenerateComboResponse> Handle(GenerateComboCommand request, CancellationToken cancellationToken)
    {
        var userId = Guid.Parse(_httpContextAccessor.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var user = await _userManager.FindByIdAsync(userId.ToString());

        // Resolve effective preferences
        UserPreference? savedPref = null;
        if (request.PreferenceId.HasValue)
        {
            savedPref = await _prefRepo.GetByIdAsync(request.PreferenceId.Value, cancellationToken);
            if (savedPref == null || savedPref.UserId != userId)
                throw new KeyNotFoundException("Preference not found.");
        }

        var maxDifficulty = request.Overrides?.MaxDifficulty ?? savedPref?.MaxDifficulty ?? 10;
        var comboLength = request.Overrides?.ComboLength ?? savedPref?.ComboLength ?? 6;
        var strongFootPct = request.Overrides?.StrongFootPercentage ?? savedPref?.StrongFootPercentage ?? 60;
        var noTouchPct = request.Overrides?.NoTouchPercentage ?? savedPref?.NoTouchPercentage ?? 30;
        var maxConsecutiveNoTouch = request.Overrides?.MaxConsecutiveNoTouch ?? savedPref?.MaxConsecutiveNoTouch ?? 2;
        var includeCrossOver = request.Overrides?.IncludeCrossOver ?? savedPref?.IncludeCrossOver ?? true;
        var includeKnee = request.Overrides?.IncludeKnee ?? savedPref?.IncludeKnee ?? true;
        var allowedRevolutions = request.Overrides?.AllowedRevolutions ?? savedPref?.AllowedRevolutions ?? [];

        // Step 1 — Filter trick pool (exclude transition tricks from random selection)
        var allTricks = await _trickRepo.GetAllAsync(ct: cancellationToken);
        var transitionTrick = allTricks.FirstOrDefault(t => t.IsTransition);
        var pool = allTricks.Where(t => !t.IsTransition && t.Difficulty <= maxDifficulty).ToList();

        if (!includeCrossOver) pool = pool.Where(t => !t.CrossOver).ToList();
        if (!includeKnee) pool = pool.Where(t => !t.Knee).ToList();
        if (allowedRevolutions.Count > 0) pool = pool.Where(t => allowedRevolutions.Contains(t.Revolution)).ToList();

        if (pool.Count == 0)
            throw new InvalidOperationException("No tricks match your preferences.");

        // Step 2 — Split into sub-pools
        var warnings = new List<string>();
        var strongPool = pool.Where(t => !t.CrossOver).ToList();
        var weakPool = pool.Where(t => t.CrossOver).ToList();

        var strongSlots = (int)Math.Round(comboLength * strongFootPct / 100.0);
        var weakSlots = comboLength - strongSlots;

        if (strongPool.Count == 0)
        {
            warnings.Add("No strong-foot tricks available; using weak-foot pool for all slots.");
            strongPool = weakPool;
        }
        if (weakPool.Count == 0)
        {
            warnings.Add("No weak-foot tricks available; using strong-foot pool for all slots.");
            weakPool = strongPool;
        }

        // Step 3 — Weighted random selection
        var rng = new Random();
        var slots = new List<(Trick Trick, bool StrongFoot)>();

        for (int i = 0; i < strongSlots; i++)
            slots.Add((WeightedPick(strongPool, rng), true));

        for (int i = 0; i < weakSlots; i++)
            slots.Add((WeightedPick(weakPool, rng), false));

        // Step 4 — Sequence (constraint-aware ordering + transition trick insertion)
        slots = ComboSequencer.Sequence(slots, rng, transitionTrick);

        // Step 5 — Annotate NoTouch (any trick after a CrossOver trick can be no-touch)
        var comboTricks = new List<(Trick Trick, bool StrongFoot, bool NoTouch, int Position)>();
        int consecutiveNoTouch = 0;

        for (int i = 0; i < slots.Count; i++)
        {
            var (trick, strongFoot) = slots[i];
            bool noTouch = false;

            if (i > 0 && slots[i - 1].Trick.CrossOver && !slots[i - 1].Trick.IsTransition && consecutiveNoTouch < maxConsecutiveNoTouch)
            {
                var roll = rng.Next(1, 101);
                noTouch = roll <= noTouchPct;
            }

            consecutiveNoTouch = noTouch ? consecutiveNoTouch + 1 : 0;
            comboTricks.Add((trick, strongFoot, noTouch, i + 1));
        }

        // Build display text
        var displayText = string.Join(" ", comboTricks.Select(ct2 =>
            ct2.NoTouch ? $"{ct2.Trick.Abbreviation}(nt)" : ct2.Trick.Abbreviation));

        // Step 6 — Get AI description
        var enhancementReq = new ComboEnhancementRequest
        {
            AverageDifficulty = Math.Round((double)comboTricks.Sum(ct2 => ct2.Trick.Difficulty) / comboTricks.Count, 1),
            Tricks = comboTricks.Select(ct2 => new TrickInfo
            {
                Name = ct2.Trick.Name,
                Abbreviation = ct2.Trick.Abbreviation,
                Revolution = ct2.Trick.Revolution,
                CrossOver = ct2.Trick.CrossOver,
                Difficulty = ct2.Trick.Difficulty,
                StrongFoot = ct2.StrongFoot,
                NoTouch = ct2.NoTouch,
                Position = ct2.Position
            }).ToList()
        };

        var aiResult = await _enhancer.EnhanceAsync(enhancementReq, cancellationToken);

        // Save combo
        var combo = new Combo
        {
            Id = Guid.NewGuid(),
            OwnerId = userId,
            Name = string.IsNullOrWhiteSpace(request.Name) ? null : request.Name.Trim(),
            AverageDifficulty = enhancementReq.AverageDifficulty,
            TrickCount = comboTricks.Count,
            Visibility = ComboVisibility.Private,
            CreatedAt = DateTime.UtcNow,
            AiDescription = string.IsNullOrEmpty(aiResult.Description) ? null : aiResult.Description,
            ComboTricks = comboTricks.Select(ct2 => new ComboTrick
            {
                Id = Guid.NewGuid(),
                TrickId = ct2.Trick.Id,
                Position = ct2.Position,
                StrongFoot = ct2.StrongFoot,
                NoTouch = ct2.NoTouch
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
            AiDescription = combo.AiDescription,
            Warnings = warnings,
            Tricks = comboTricks.Select(ct2 => new ComboTrickDto
            {
                TrickId = ct2.Trick.Id,
                Name = ct2.Trick.Name,
                Abbreviation = ct2.Trick.Abbreviation,
                Position = ct2.Position,
                StrongFoot = ct2.StrongFoot,
                NoTouch = ct2.NoTouch,
                Difficulty = ct2.Trick.Difficulty,
                Revolution = ct2.Trick.Revolution,
                CrossOver = ct2.Trick.CrossOver,
                IsTransition = ct2.Trick.IsTransition
            }).ToList()
        };
    }

    private static Trick WeightedPick(List<Trick> pool, Random rng)
    {
        var totalWeight = pool.Sum(t => t.CommonLevel);
        var roll = rng.Next(1, totalWeight + 1);
        int acc = 0;
        foreach (var trick in pool)
        {
            acc += trick.CommonLevel;
            if (roll <= acc) return trick;
        }
        return pool[^1];
    }
}
