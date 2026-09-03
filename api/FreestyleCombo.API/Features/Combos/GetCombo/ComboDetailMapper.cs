using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.Core.Entities;

namespace FreestyleCombo.API.Features.Combos.GetCombo;

internal static class ComboDetailMapper
{
    public static ComboDetailDto Map(
        Combo combo,
        bool isFavourited,
        bool isCompleted,
        bool isPersonalReusable,
        int completionCount)
    {
        var displayText = string.Join(" ", combo.ComboTricks.OrderBy(ct => ct.Position).Select(ct =>
        {
            if (ct.TrickId.HasValue)
                return ct.NoTouch ? $"{ct.Trick!.Abbreviation}(nt)" : ct.Trick!.Abbreviation;
            else
            {
                var inner = string.Join(" ", ct.SubCombo!.ComboTricks
                    .Where(sct => sct.TrickId.HasValue)
                    .OrderBy(sct => sct.Position)
                    .Select(sct => sct.Trick!.Abbreviation));
                return $"[{ct.SubCombo.Name}: {inner}]";
            }
        }));

        var avgRating = combo.Ratings.Any() ? combo.Ratings.Average(r => r.Score) : 0;

        return new ComboDetailDto
        {
            Id = combo.Id,
            OwnerId = combo.OwnerId,
            OwnerUserName = combo.Owner?.UserName,
            Name = combo.Name,
            TotalDifficulty = combo.TotalDifficulty,
            TrickCount = combo.TrickCount,
            IsPublic = combo.IsPublic,
            Visibility = combo.Visibility.ToString(),
            CreatedAt = combo.CreatedAt,
            DisplayText = displayText,
            AiDescription = combo.AiDescription,
            AverageRating = Math.Round(avgRating, 2),
            TotalRatings = combo.Ratings.Count,
            IsFavourited = isFavourited,
            IsCompleted = isCompleted,
            CompletionCount = completionCount,
            IsReusable = combo.IsReusable,
            IsPersonalReusable = isPersonalReusable,
            Tricks = combo.ComboTricks.OrderBy(ct => ct.Position).Select(ct =>
            {
                if (ct.TrickId.HasValue)
                    return new ComboTrickDto
                    {
                        Type = "trick",
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
                    };
                else
                    return new ComboTrickDto
                    {
                        Type = "combo",
                        SubComboId = ct.SubComboId,
                        SubComboName = ct.SubCombo?.Name,
                        Position = ct.Position,
                        SubComboTricks = ct.SubCombo?.ComboTricks
                            .Where(sct => sct.TrickId.HasValue)
                            .OrderBy(sct => sct.Position)
                            .Select(sct => new ComboTrickDto
                            {
                                Type = "trick",
                                TrickId = sct.TrickId,
                                Name = sct.Trick!.Name,
                                Abbreviation = sct.Trick.Abbreviation,
                                Position = sct.Position,
                                Difficulty = sct.Trick.Difficulty,
                                Revolution = sct.Trick.Revolution,
                                CrossOver = sct.Trick.CrossOver,
                                IsTransition = sct.Trick.IsTransition,
                                StrongFoot = sct.StrongFoot,
                                NoTouch = sct.NoTouch
                            }).ToList()
                    };
            }).ToList()
        };
    }
}
