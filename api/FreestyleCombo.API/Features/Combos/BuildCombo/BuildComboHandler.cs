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

        // Validate XOR: each slot must have exactly one of TrickId / SubComboId
        if (request.Tricks.Any(t => (t.TrickId == null) == (t.SubComboId == null)))
            throw new InvalidOperationException("Each slot must have exactly one of TrickId or SubComboId.");

        // Separate trick slots and sub-combo slots
        var trickSlots = request.Tricks.Where(t => t.TrickId != null).ToList();
        var subComboSlots = request.Tricks.Where(t => t.SubComboId != null).ToList();

        // Load and validate tricks
        var trickIds = trickSlots.Select(t => t.TrickId!.Value).Distinct().ToList();
        var allTricks = await _trickRepo.GetAllAsync(ct: cancellationToken);
        var trickMap = allTricks.Where(t => trickIds.Contains(t.Id)).ToDictionary(t => t.Id);
        var missing = trickIds.Except(trickMap.Keys).ToList();
        if (missing.Count > 0)
            throw new KeyNotFoundException($"Trick(s) not found: {string.Join(", ", missing)}");

        // Load and validate sub-combos
        var subComboIds = subComboSlots.Select(t => t.SubComboId!.Value).Distinct().ToList();
        var subComboMap = new Dictionary<Guid, Combo>();
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

        // Normalize trick slots: strip NoTouch/StrongFoot from transitions; NT allowed only if previous slot's last trick is CO
        var allSlotsByPos = request.Tricks.OrderBy(t => t.Position).ToList();
        var normalizedTricks = new List<BuildComboTrickItem>();
        for (int i = 0; i < allSlotsByPos.Count; i++)
        {
            var t = allSlotsByPos[i];
            if (t.TrickId == null) continue;
            var trick = trickMap[t.TrickId!.Value];
            if (trick.IsTransition) { normalizedTricks.Add(t with { NoTouch = false, StrongFoot = false }); continue; }
            bool prevIsCO = false;
            if (i > 0)
            {
                var prev = allSlotsByPos[i - 1];
                if (prev.TrickId != null && trickMap.TryGetValue(prev.TrickId.Value, out var pt))
                    prevIsCO = pt.CrossOver;
                else if (prev.SubComboId != null && subComboMap.TryGetValue(prev.SubComboId.Value, out var psc))
                    prevIsCO = psc.ComboTricks.Where(ct => ct.TrickId != null).OrderBy(ct => ct.Position).LastOrDefault()?.Trick?.CrossOver ?? false;
            }
            normalizedTricks.Add(t with { NoTouch = t.NoTouch && prevIsCO });
        }

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

        // Build DisplayText
        var displayText = string.Join(" ", allSlots.Select(t =>
        {
            if (t.TrickId != null)
            {
                var norm = normalizedTricks.First(n => n.Position == t.Position);
                return norm.NoTouch ? $"{trickMap[t.TrickId!.Value].Abbreviation}(nt)" : trickMap[t.TrickId!.Value].Abbreviation;
            }
            else
            {
                var sc = subComboMap[t.SubComboId!.Value];
                var inner = string.Join(" ", sc.ComboTricks
                    .Where(ct => ct.TrickId != null)
                    .OrderBy(ct => ct.Position)
                    .Select(ct => ct.Trick!.Abbreviation));
                return $"[{sc.Name}: {inner}]";
            }
        }));

        // Build ComboTrick rows
        var comboTricks = allSlots.Select(t =>
        {
            if (t.TrickId != null)
            {
                var norm = normalizedTricks.First(n => n.Position == t.Position);
                return new ComboTrick
                {
                    Id = Guid.NewGuid(),
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
                    TrickId = null,
                    SubComboId = t.SubComboId,
                    Position = t.Position,
                    StrongFoot = false,
                    NoTouch = false
                };
            }
        }).ToList();

        var combo = new Combo
        {
            Id = Guid.NewGuid(),
            OwnerId = userId,
            Name = string.IsNullOrWhiteSpace(request.Name) ? null : request.Name.Trim(),
            TotalDifficulty = totalDifficulty,
            TrickCount = totalTrickCount,
            Visibility = request.IsPublic
                ? (isAdmin ? ComboVisibility.Public : ComboVisibility.PendingReview)
                : ComboVisibility.Private,
            CreatedAt = DateTime.UtcNow,
            AiDescription = null,
            ComboTricks = comboTricks
        };

        await _comboRepo.AddAsync(combo, cancellationToken);

        // Build response Tricks list
        var responseTricks = allSlots.Select(t =>
        {
            if (t.TrickId != null)
            {
                var trick = trickMap[t.TrickId!.Value];
                var norm = normalizedTricks.First(n => n.Position == t.Position);
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
                var sc = subComboMap[t.SubComboId!.Value];
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
            OwnerUserName = user?.UserName,
            Name = combo.Name,
            TotalDifficulty = combo.TotalDifficulty,
            TrickCount = combo.TrickCount,
            IsPublic = combo.IsPublic,
            IsReusable = combo.IsReusable,
            Visibility = combo.Visibility.ToString(),
            CreatedAt = combo.CreatedAt,
            DisplayText = displayText,
            AiDescription = null,
            Warnings = [],
            Tricks = responseTricks
        };
    }
}
