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

        // When a field has no override and no saved-preference value, pick a random
        // value within a sensible range for THIS generation only — nothing here is
        // persisted, it's a fresh roll every call so an "everything off" combo comes
        // out varied instead of always hitting the same fixed numbers. Revolutions
        // and AllowedTrickIds keep their existing "empty = no restriction" meaning —
        // there's no sensible random range for those two.
        var maxDifficulty = request.Overrides?.MaxDifficulty ?? savedPref?.MaxDifficulty ?? Random.Shared.Next(4, 9);
        var comboLength = request.Overrides?.ComboLength ?? savedPref?.ComboLength ?? Random.Shared.Next(5, 21);
        var strongFootPct = request.Overrides?.StrongFootPercentage ?? savedPref?.StrongFootPercentage ?? Random.Shared.Next(40, 91);
        var noTouchPct = request.Overrides?.NoTouchPercentage ?? savedPref?.NoTouchPercentage ?? Random.Shared.Next(5, 51);
        var maxConsecutiveNoTouch = request.Overrides?.MaxConsecutiveNoTouch ?? savedPref?.MaxConsecutiveNoTouch ?? Random.Shared.Next(4, 11);
        var includeCrossOver = request.Overrides?.IncludeCrossOver ?? savedPref?.IncludeCrossOver ?? true;
        var includeKnee = request.Overrides?.IncludeKnee ?? savedPref?.IncludeKnee ?? false;
        var allowedRevolutions = request.Overrides?.AllowedRevolutions ?? savedPref?.AllowedRevolutions ?? [];
        var maxHighRevolutionTricks = request.Overrides?.MaxHighRevolutionTricks ?? savedPref?.MaxHighRevolutionTricks ?? (int?)Random.Shared.Next(1, 4);
        var allowedTrickIds = request.Overrides?.AllowedTrickIds ?? savedPref?.AllowedTrickIds ?? [];

        // Step 1 — Filter trick pool (exclude transition tricks from random selection)
        var allTricks = await _trickRepo.GetAllAsync(ct: cancellationToken);
        var transitionTrick = allTricks.FirstOrDefault(t => t.IsTransition);
        var pool = allTricks.Where(t => !t.IsTransition && t.Difficulty <= maxDifficulty).ToList();

        if (!includeCrossOver) pool = pool.Where(t => !t.CrossOver).ToList();
        if (!includeKnee) pool = pool.Where(t => !t.Knee).ToList();
        if (allowedRevolutions.Count > 0) pool = pool.Where(t => allowedRevolutions.Contains(t.Revolution)).ToList();
        if (allowedTrickIds.Count > 0) pool = pool.Where(t => allowedTrickIds.Contains(t.Id)).ToList();

        if (pool.Count == 0)
            throw new InvalidOperationException("No tricks match your preferences.");

        // Steps 2–4 — Build the sequenced combo. `comboLength` is the target FINAL
        // slot count (real tricks + any transition "combo" bridges Step 4 inserts
        // between adjacent tricks that switch CrossOver type — see
        // ComboSequencer.Sequence), but only real tricks are picked up front, and
        // how many transitions land depends on the final order, which isn't known
        // until sequencing runs. So each attempt guesses a real-trick count, runs
        // the pipeline, and — if the resulting total misses the target — adjusts
        // the guess by the exact miss and tries again. Transition count correlates
        // closely with real-trick count for a given pool/%-mix, so this converges
        // within a couple of attempts in practice; the closest attempt is kept if
        // it never converges exactly.
        var warnings = new List<string>();
        var slots = new List<(Trick Trick, bool StrongFoot)>();
        var rng = new Random();
        const decimal highRevThreshold = 3m;
        var realCount = comboLength;
        var bestDiffAbs = int.MaxValue;

        for (int attempt = 0; attempt < 8; attempt++)
        {
            realCount = Math.Max(1, realCount);

            // Step 2 — Split slot count by strong/weak foot percentage. Which foot
            // performs a trick is independent of whether the trick itself is a
            // CrossOver move (an intrinsic Trick property) — both slot kinds draw
            // from the same pool.
            var strongSlots = (int)Math.Round(realCount * strongFootPct / 100.0);
            var weakSlots = realCount - strongSlots;

            // Step 3 — Weighted random selection
            var attemptSlots = new List<(Trick Trick, bool StrongFoot)>();

            for (int i = 0; i < strongSlots; i++)
                attemptSlots.Add((WeightedPick(pool, rng), true));

            for (int i = 0; i < weakSlots; i++)
                attemptSlots.Add((WeightedPick(pool, rng), false));

            // Step 3.5 — Cap tricks with 3+ revolutions (the hardest, rarest moves)
            var attemptWarnings = new List<string>();
            if (maxHighRevolutionTricks.HasValue)
            {
                var lowRevPool = pool.Where(t => t.Revolution < highRevThreshold).ToList();
                var highRevIndices = attemptSlots
                    .Select((s, idx) => (s.Trick, idx))
                    .Where(x => x.Trick.Revolution >= highRevThreshold)
                    .Select(x => x.idx)
                    .ToList();

                if (highRevIndices.Count > maxHighRevolutionTricks.Value)
                {
                    if (lowRevPool.Count == 0)
                    {
                        attemptWarnings.Add($"Could not enforce max {maxHighRevolutionTricks.Value} tricks with 3+ revolutions — no lower-revolution tricks match your other preferences.");
                    }
                    else
                    {
                        var toReplace = highRevIndices.OrderBy(_ => rng.Next()).Skip(maxHighRevolutionTricks.Value);
                        foreach (var idx in toReplace)
                            attemptSlots[idx] = (WeightedPick(lowRevPool, rng), attemptSlots[idx].StrongFoot);
                    }
                }
            }

            // Step 4 — Sequence (constraint-aware ordering + transition trick insertion)
            attemptSlots = ComboSequencer.Sequence(attemptSlots, rng, transitionTrick);

            var diff = comboLength - attemptSlots.Count;
            if (Math.Abs(diff) < bestDiffAbs)
            {
                bestDiffAbs = Math.Abs(diff);
                slots = attemptSlots;
                warnings = attemptWarnings;
            }
            if (diff == 0) break;
            realCount += diff;
        }

        // Guarantee an exact match: the reroll loop above usually converges, but for
        // longer combos the transition count has enough natural variance that it
        // sometimes doesn't (see the loop's comment) — as a deterministic fallback,
        // trim or pad the closest attempt to hit the target exactly. Trimming prefers
        // dropping transition "combo" bridges first (their absence is only cosmetic,
        // and it also nudges the strong/weak split back toward target since
        // transitions are always weak-foot); padding tops up with more real tricks,
        // favoring whichever foot is currently under its target proportion.
        if (slots.Count > comboLength)
        {
            var excess = slots.Count - comboLength;
            for (int i = slots.Count - 1; i >= 0 && excess > 0; i--)
            {
                if (slots[i].Trick.IsTransition)
                {
                    slots.RemoveAt(i);
                    excess--;
                }
            }
            while (excess > 0)
            {
                slots.RemoveAt(slots.Count - 1);
                excess--;
            }
        }
        else if (slots.Count < comboLength)
        {
            var strongCount = slots.Count(s => s.StrongFoot);
            while (slots.Count < comboLength)
            {
                var wantStrong = (double)strongCount / Math.Max(1, slots.Count) < strongFootPct / 100.0;
                slots.Add((WeightedPick(pool, rng), wantStrong));
                if (wantStrong) strongCount++;
            }
        }

        // Step 5 — Annotate NoTouch (any trick after a CrossOver trick can be no-touch)
        var comboTricks = new List<(Trick Trick, bool StrongFoot, bool NoTouch, int Position)>();
        int consecutiveNoTouch = 0;

        for (int i = 0; i < slots.Count; i++)
        {
            var (trick, strongFoot) = slots[i];
            bool noTouch = false;

            if (!trick.IsTransition && i > 0 && slots[i - 1].Trick.CrossOver && !slots[i - 1].Trick.IsTransition && consecutiveNoTouch < maxConsecutiveNoTouch)
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
            TotalDifficulty = (double)comboTricks.Sum(ct2 => ct2.Trick.Difficulty) + comboTricks.Sum(ct2 => (ct2.NoTouch ? 1 : 0) + (!ct2.StrongFoot ? 1 : 0)),
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
            TotalDifficulty = enhancementReq.TotalDifficulty,
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
            TotalDifficulty = combo.TotalDifficulty,
            TrickCount = combo.TrickCount,
            IsPublic = combo.IsPublic,
            IsReusable = combo.IsReusable,
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
