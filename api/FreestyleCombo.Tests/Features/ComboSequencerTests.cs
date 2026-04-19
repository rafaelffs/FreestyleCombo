using FluentAssertions;
using FreestyleCombo.API.Features.Combos;
using FreestyleCombo.Tests.Helpers;

namespace FreestyleCombo.Tests.Features;

public class ComboSequencerTests
{
    [Fact]
    public void Sequence_RarelyPlacesTwoHighRevTricksAdjacent()
    {
        // 3 high-rev tricks mixed with 3 low-rev tricks
        var highRev1 = TrickFaker.Create(revolution: 3.0m, commonLevel: 5);
        var highRev2 = TrickFaker.Create(revolution: 3.5m, commonLevel: 5);
        var highRev3 = TrickFaker.Create(revolution: 4.0m, commonLevel: 5);
        var low1 = TrickFaker.Create(revolution: 1.0m, commonLevel: 5);
        var low2 = TrickFaker.Create(revolution: 1.0m, commonLevel: 5);
        var low3 = TrickFaker.Create(revolution: 1.0m, commonLevel: 5);

        var slots = new List<(FreestyleCombo.Core.Entities.Trick, bool)>
        {
            (highRev1, true), (highRev2, true), (highRev3, true),
            (low1, false), (low2, false), (low3, false)
        };

        int adjacentHighRevCount = 0;
        int totalPairs = 0;
        for (int seed = 0; seed < 200; seed++)
        {
            var result = ComboSequencer.Sequence(slots.ToList(), new Random(seed));
            for (int i = 1; i < result.Count; i++)
            {
                totalPairs++;
                if (result[i - 1].Trick.Revolution >= 3 && result[i].Trick.Revolution >= 3)
                    adjacentHighRevCount++;
            }
        }

        // Adjacent high-rev pairs should be rare — well under 20% of all pairs
        var rate = (double)adjacentHighRevCount / totalPairs;
        rate.Should().BeLessThan(0.20, $"consecutive high-rev rate {rate:P0} should be low");
    }

    [Fact]
    public void Sequence_FallsBackToAnyCandidate_WhenHardConstraintWouldExcludeAll()
    {
        // All tricks are high-rev — hard constraint can never be satisfied, must not throw
        var slots = Enumerable.Range(0, 4)
            .Select(_ => (TrickFaker.Create(revolution: 3.0m, commonLevel: 3), false))
            .ToList();

        var act = () => ComboSequencer.Sequence(slots, new Random(42));

        act.Should().NotThrow();
        var result = act();
        result.Should().HaveCount(4);
    }

    [Fact]
    public void Sequence_PrefersHighRevOpener_WhenAvgDifficultyIsHigh()
    {
        // One high-rev trick among high-difficulty tricks (avg difficulty = 8 → opener preference kicks in)
        var highRevTrick = TrickFaker.Create(revolution: 3.0m, difficulty: 8, commonLevel: 1);
        var others = Enumerable.Range(0, 4)
            .Select(_ => TrickFaker.Create(revolution: 1.0m, difficulty: 8, commonLevel: 1))
            .ToList();

        var slots = others.Select(t => (t, false)).ToList();
        slots.Add((highRevTrick, true));

        // Run many seeds — opener should always be the high-rev trick
        for (int seed = 0; seed < 50; seed++)
        {
            var result = ComboSequencer.Sequence(slots.ToList(), new Random(seed));
            result[0].Trick.Revolution.Should().Be(3.0m,
                $"seed {seed}: expected high-rev opener when avg difficulty >= 7");
        }
    }

    [Fact]
    public void Sequence_ReturnsAllInputSlots_WithNoLoss()
    {
        var tricks = TrickFaker.DefaultPool();
        var slots = tricks.Select(t => (t, t.CrossOver)).ToList();

        var result = ComboSequencer.Sequence(slots.ToList(), new Random(0));

        result.Should().HaveCount(slots.Count);
        result.Select(s => s.Trick.Id).Should().BeEquivalentTo(slots.Select(s => s.Item1.Id));
    }
}
