using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;

namespace FreestyleCombo.Infrastructure.Seed;

public static class TrickSeeder
{
    public static async Task SeedAsync(ITrickRepository repo, CancellationToken ct = default)
    {
        if (!await repo.IsEmptyAsync(ct))
            return;

        var tricks = new List<Trick>
        {
            new() { Id = Guid.NewGuid(), Name = "Around the World",              Abbreviation = "ATW",   Motion = 1.0m, CrossOver = false, Knee = false, Difficulty = 1, CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Hop the World",                 Abbreviation = "HTW",   Motion = 1.0m, CrossOver = false, Knee = false, Difficulty = 1, CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Crossover",                     Abbreviation = "XO",    Motion = 1.0m, CrossOver = true,  Knee = false, Difficulty = 1, CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Reverse Crossover",             Abbreviation = "RXO",   Motion = 1.0m, CrossOver = true,  Knee = false, Difficulty = 1, CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Mitch Around the World",        Abbreviation = "MATW",  Motion = 1.5m, CrossOver = true,  Knee = false, Difficulty = 1, CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Lemmens Around the World",      Abbreviation = "LATW",  Motion = 2.0m, CrossOver = false, Knee = false, Difficulty = 2, CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Touzani Around the World",      Abbreviation = "TATW",  Motion = 1.5m, CrossOver = true,  Knee = false, Difficulty = 1, CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Palle Around the World",        Abbreviation = "PATW",  Motion = 3.0m, CrossOver = false, Knee = false, Difficulty = 6, CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Lemmens Touzani Around the World", Abbreviation = "LTATW", Motion = 2.5m, CrossOver = true, Knee = false, Difficulty = 3, CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Palle Mitch Around the World",  Abbreviation = "PMATW", Motion = 3.5m, CrossOver = false, Knee = false, Difficulty = 8, CommonLevel = 1 },
        };

        foreach (var trick in tricks)
            await repo.AddAsync(trick, ct);
    }
}
