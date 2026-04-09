using FreestyleCombo.Core.Entities;

namespace FreestyleCombo.Tests.Helpers;

public static class TrickFaker
{
    private static int _counter = 0;

    public static Trick Create(
        string? name = null,
        bool crossOver = false,
        bool knee = false,
        decimal motion = 1.0m,
        int difficulty = 2,
        int commonLevel = 3)
    {
        _counter++;
        return new Trick
        {
            Id = Guid.NewGuid(),
            Name = name ?? $"Trick {_counter}",
            Abbreviation = $"T{_counter}",
            CrossOver = crossOver,
            Knee = knee,
            Motion = motion,
            Difficulty = difficulty,
            CommonLevel = commonLevel
        };
    }

    public static List<Trick> CreateMany(int count, bool crossOver = false)
    {
        return Enumerable.Range(0, count).Select(_ => Create(crossOver: crossOver)).ToList();
    }

    public static List<Trick> DefaultPool()
    {
        return
        [
            Create("ATW",  crossOver: false, difficulty: 1, commonLevel: 5),
            Create("HTW",  crossOver: false, difficulty: 1, commonLevel: 5),
            Create("XO",   crossOver: true,  difficulty: 1, commonLevel: 5),
            Create("MATW", crossOver: true,  difficulty: 1, commonLevel: 4),
            Create("TATW", crossOver: true,  difficulty: 1, commonLevel: 4),
            Create("LATW", crossOver: false, difficulty: 2, commonLevel: 3),
        ];
    }
}
