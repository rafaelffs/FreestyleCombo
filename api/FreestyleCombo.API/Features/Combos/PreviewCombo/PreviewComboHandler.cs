using System.Security.Claims;
using FreestyleCombo.API.Features.Combos;
using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace FreestyleCombo.API.Features.Combos.PreviewCombo;

public class PreviewComboHandler : IRequestHandler<PreviewComboCommand, PreviewComboResponse>
{
    private readonly ITrickRepository _trickRepo;
    private readonly IUserPreferenceRepository _prefRepo;
    private readonly IHttpContextAccessor _httpContextAccessor;

    public PreviewComboHandler(
        ITrickRepository trickRepo,
        IUserPreferenceRepository prefRepo,
        IHttpContextAccessor httpContextAccessor)
    {
        _trickRepo = trickRepo;
        _prefRepo = prefRepo;
        _httpContextAccessor = httpContextAccessor;
    }

    public async Task<PreviewComboResponse> Handle(PreviewComboCommand request, CancellationToken cancellationToken)
    {
        var userId = Guid.Parse(_httpContextAccessor.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!);

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

        // Step 5 — Annotate NoTouch
        var result = new List<PreviewTrickItem>();
        int consecutiveNoTouch = 0;

        for (int i = 0; i < slots.Count; i++)
        {
            var (trick, strongFoot) = slots[i];
            bool noTouch = false;

            if (i > 0 && trick.CrossOver && consecutiveNoTouch < maxConsecutiveNoTouch)
            {
                var prevWasCross = slots[i - 1].Trick.CrossOver;
                var effectivePct = prevWasCross ? Math.Max(noTouchPct, 70) : noTouchPct;
                var roll = rng.Next(1, 101);
                noTouch = roll <= effectivePct;
            }

            consecutiveNoTouch = noTouch ? consecutiveNoTouch + 1 : 0;

            result.Add(new PreviewTrickItem
            {
                TrickId = trick.Id,
                TrickName = trick.Name,
                Abbreviation = trick.Abbreviation,
                Position = i + 1,
                StrongFoot = strongFoot,
                NoTouch = noTouch,
                Difficulty = trick.Difficulty,
                CrossOver = trick.CrossOver,
                Revolution = trick.Revolution
            });
        }

        return new PreviewComboResponse { Tricks = result, Warnings = warnings };
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
