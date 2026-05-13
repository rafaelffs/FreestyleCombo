using System.Security.Claims;
using FreestyleCombo.API.Features.Combos.BuildCombo;
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

        // These will be populated only when tricks are replaced
        List<ComboTrick>? newComboTricks = null;
        Dictionary<Guid, Trick>? trickMap = null;
        Dictionary<Guid, Combo>? subComboMap = null;
        List<BuildComboTrickItem>? normalizedTricksOuter = null;
        List<BuildComboTrickItem>? allSlotsOrdered = null;

        // Update tricks if provided
        if (request.Tricks is { Count: > 0 })
        {
            // XOR validate: each slot must have exactly one of TrickId / SubComboId
            if (request.Tricks.Any(t => (t.TrickId == null) == (t.SubComboId == null)))
                throw new InvalidOperationException("Each slot must have exactly one of TrickId or SubComboId.");

            // Flat constraint: reusable combos cannot contain sub-combo slots
            if (combo.IsReusable && request.Tricks.Any(t => t.SubComboId != null))
                throw new InvalidOperationException("Reusable combos cannot contain sub-combo slots.");

            var trickSlots = request.Tricks.Where(t => t.TrickId != null).ToList();
            var subComboSlots = request.Tricks.Where(t => t.SubComboId != null).ToList();

            // Load and validate tricks
            var trickIds = trickSlots.Select(t => t.TrickId!.Value).Distinct().ToList();
            var allTricks = await _trickRepo.GetAllAsync(ct: cancellationToken);
            trickMap = allTricks.Where(t => trickIds.Contains(t.Id)).ToDictionary(t => t.Id);

            var missing = trickIds.Except(trickMap.Keys).ToList();
            if (missing.Count > 0)
                throw new KeyNotFoundException($"Trick(s) not found: {string.Join(", ", missing)}");

            // Load and validate sub-combos
            var subComboIds = subComboSlots.Select(t => t.SubComboId!.Value).Distinct().ToList();
            subComboMap = new Dictionary<Guid, Combo>();
            foreach (var scId in subComboIds)
            {
                var sc = await _comboRepo.GetByIdAsync(scId, cancellationToken)
                    ?? throw new KeyNotFoundException($"Sub-combo {scId} not found.");
                if (!sc.IsReusable)
                    throw new InvalidOperationException($"Combo {scId} is not reusable.");
                if (sc.ComboTricks.Any(ct => ct.SubComboId != null))
                    throw new InvalidOperationException($"Reusable combo {scId} contains nested sub-combos.");
                subComboMap[scId] = sc;
            }

            // Normalize trick slots: strip NoTouch/StrongFoot from transitions; strip NoTouch from non-CrossOver
            var normalizedTricks = trickSlots
                .Select(t => trickMap[t.TrickId!.Value].IsTransition
                    ? t with { NoTouch = false, StrongFoot = false }
                    : t with { NoTouch = t.NoTouch && trickMap[t.TrickId!.Value].CrossOver })
                .ToList();

            // Calculate TrickCount (direct tricks + expanded sub-combo tricks)
            var directTrickCount = normalizedTricks.Count;
            var subComboTrickCount = subComboSlots.Sum(s => subComboMap[s.SubComboId!.Value].ComboTricks.Count(ct => ct.TrickId != null));
            var totalTrickCount = directTrickCount + subComboTrickCount;

            // Calculate TotalDifficulty: base difficulty + 1 per NoTouch, + 1 per WeakFoot
            var allDifficulties = normalizedTricks
                .Select(t => (double)trickMap[t.TrickId!.Value].Difficulty + (t.NoTouch ? 1 : 0) + (!t.StrongFoot ? 1 : 0))
                .Concat(subComboSlots.SelectMany(s => subComboMap[s.SubComboId!.Value].ComboTricks
                    .Where(ct => ct.TrickId != null)
                    .Select(ct => (double)ct.Trick!.Difficulty + (ct.NoTouch ? 1 : 0) + (!ct.StrongFoot ? 1 : 0))))
                .ToList();
            var totalDifficulty = allDifficulties.Sum();

            // Order all slots by position
            var allSlots = request.Tricks.OrderBy(t => t.Position).ToList();
            allSlotsOrdered = allSlots;
            normalizedTricksOuter = normalizedTricks;

            // Build new ComboTrick rows
            newComboTricks = allSlots.Select(t =>
            {
                if (t.TrickId != null)
                {
                    var norm = normalizedTricks.First(n => n.Position == t.Position);
                    return new ComboTrick
                    {
                        Id = Guid.NewGuid(),
                        ComboId = combo.Id,
                        TrickId = t.TrickId,
                        SubComboId = null,
                        Position = t.Position,
                        StrongFoot = norm.StrongFoot,
                        NoTouch = norm.NoTouch
                    };
                }
                else
                {
                    return new ComboTrick
                    {
                        Id = Guid.NewGuid(),
                        ComboId = combo.Id,
                        TrickId = null,
                        SubComboId = t.SubComboId,
                        Position = t.Position,
                        StrongFoot = false,
                        NoTouch = false
                    };
                }
            }).ToList();

            await _comboRepo.ReplaceComboTricksAsync(combo.Id, newComboTricks, cancellationToken);

            combo.TrickCount = totalTrickCount;
            combo.TotalDifficulty = totalDifficulty;
        }

        // If the combo was public, it must go back through admin review — unless the editor is an admin or the combo is reusable
        if (combo.Visibility == ComboVisibility.Public && !isAdmin && !combo.IsReusable)
            combo.Visibility = ComboVisibility.PendingReview;

        await _comboRepo.UpdateAsync(combo, cancellationToken);

        var owner = await _userManager.FindByIdAsync(combo.OwnerId.ToString());

        // Resolve slot data for response
        List<BuildComboTrickItem> allSlotsForResponse;
        List<BuildComboTrickItem> normalizedTricksForResponse;
        Dictionary<Guid, Trick> responseTrickMap;
        Dictionary<Guid, Combo> responseSubComboMap;

        if (newComboTricks != null && trickMap != null && subComboMap != null && allSlotsOrdered != null && normalizedTricksOuter != null)
        {
            allSlotsForResponse = allSlotsOrdered;
            normalizedTricksForResponse = normalizedTricksOuter;
            responseTrickMap = trickMap;
            responseSubComboMap = subComboMap;
        }
        else
        {
            // No tricks replaced — reconstruct from existing combo tricks (already normalized in DB)
            var existingTrickRows = combo.ComboTricks.Where(ct => ct.TrickId.HasValue).OrderBy(t => t.Position).ToList();
            responseTrickMap = existingTrickRows.ToDictionary(ct => ct.TrickId!.Value, ct => ct.Trick!);
            responseSubComboMap = combo.ComboTricks
                .Where(ct => ct.SubComboId.HasValue && ct.SubCombo != null)
                .ToDictionary(ct => ct.SubComboId!.Value, ct => ct.SubCombo!);
            allSlotsForResponse = combo.ComboTricks.OrderBy(ct => ct.Position).Select(ct =>
                new BuildComboTrickItem(ct.TrickId, ct.SubComboId, ct.Position, ct.StrongFoot, ct.NoTouch)
            ).ToList();
            // In the no-replace path, slots are already normalized (stored values)
            normalizedTricksForResponse = allSlotsForResponse.Where(t => t.TrickId != null).ToList();
        }

        // Build DisplayText
        var displayText = string.Join(" ", allSlotsForResponse.Select(t =>
        {
            if (t.TrickId != null)
            {
                var trick = responseTrickMap[t.TrickId!.Value];
                var norm = normalizedTricksForResponse.First(n => n.Position == t.Position);
                return norm.NoTouch ? $"{trick.Abbreviation}(nt)" : trick.Abbreviation;
            }
            else
            {
                var sc = responseSubComboMap[t.SubComboId!.Value];
                var inner = string.Join(" ", sc.ComboTricks
                    .Where(ct => ct.TrickId != null)
                    .OrderBy(ct => ct.Position)
                    .Select(ct => ct.Trick!.Abbreviation));
                return $"[{sc.Name}: {inner}]";
            }
        }));

        // Build response Tricks list
        var responseTricks = allSlotsForResponse.Select(t =>
        {
            if (t.TrickId != null)
            {
                var trick = responseTrickMap[t.TrickId!.Value];
                var norm = normalizedTricksForResponse.First(n => n.Position == t.Position);
                return new ComboTrickDto
                {
                    Type = "trick",
                    TrickId = trick.Id,
                    Name = trick.Name,
                    Abbreviation = trick.Abbreviation,
                    Position = t.Position,
                    StrongFoot = norm.StrongFoot,
                    NoTouch = norm.NoTouch,
                    Difficulty = trick.Difficulty,
                    Revolution = trick.Revolution,
                    CrossOver = trick.CrossOver,
                    IsTransition = trick.IsTransition
                };
            }
            else
            {
                var sc = responseSubComboMap[t.SubComboId!.Value];
                return new ComboTrickDto
                {
                    Type = "combo",
                    SubComboId = sc.Id,
                    SubComboName = sc.Name,
                    Position = t.Position,
                    SubComboTricks = sc.ComboTricks
                        .Where(ct => ct.TrickId != null)
                        .OrderBy(ct => ct.Position)
                        .Select(ct => new ComboTrickDto
                        {
                            Type = "trick",
                            TrickId = ct.TrickId,
                            Name = ct.Trick!.Name,
                            Abbreviation = ct.Trick.Abbreviation,
                            Position = ct.Position,
                            Difficulty = ct.Trick.Difficulty,
                            Revolution = ct.Trick.Revolution,
                            CrossOver = ct.Trick.CrossOver,
                            IsTransition = ct.Trick.IsTransition
                        }).ToList()
                };
            }
        }).ToList();

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
            Tricks = responseTricks
        };
    }
}
