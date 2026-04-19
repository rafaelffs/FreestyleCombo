using FreestyleCombo.Core.Entities;

namespace FreestyleCombo.API.Features.Combos;

public static class ComboSequencer
{
    /// <summary>
    /// Orders slots using constraint-aware sequencing, then inserts the transition trick
    /// (e.g. "combo") between any pair of adjacent tricks that switch foot type.
    /// </summary>
    public static List<(Trick Trick, bool StrongFoot)> Sequence(
        List<(Trick Trick, bool StrongFoot)> slots,
        Random rng,
        Trick? transitionTrick = null)
    {
        if (slots.Count == 0) return slots;

        var ordered = slots.Count == 1 ? slots : OrderSlots(slots, rng);

        if (transitionTrick == null) return ordered;

        // Insert transition trick between any two consecutive tricks that switch foot type
        var result = new List<(Trick, bool)>(ordered.Count * 2);
        result.Add(ordered[0]);
        for (int i = 1; i < ordered.Count; i++)
        {
            if (ordered[i - 1].Trick.CrossOver != ordered[i].Trick.CrossOver)
                result.Add((transitionTrick, false));
            result.Add(ordered[i]);
        }
        return result;
    }

    private static List<(Trick Trick, bool StrongFoot)> OrderSlots(
        List<(Trick Trick, bool StrongFoot)> slots,
        Random rng)
    {
        var remaining = slots.ToList();
        var result = new List<(Trick Trick, bool StrongFoot)>(slots.Count);

        var avgDifficulty = slots.Average(s => s.Trick.Difficulty);
        var first = PickOpening(remaining, avgDifficulty, rng);
        result.Add(first);
        remaining.Remove(first);

        while (remaining.Count > 0)
        {
            var prev = result[^1].Trick;
            var isLastSlot = result.Count == slots.Count - 1;
            var next = WeightedPickWithContext(remaining, prev, isLastSlot, rng);
            result.Add(next);
            remaining.Remove(next);
        }

        return result;
    }

    private static (Trick, bool) PickOpening(
        List<(Trick Trick, bool StrongFoot)> pool,
        double avgDifficulty,
        Random rng)
    {
        if (avgDifficulty >= 7)
        {
            var highRev = pool.Where(s => s.Trick.Revolution >= 3).ToList();
            if (highRev.Count > 0)
                return highRev[rng.Next(highRev.Count)];
        }
        return pool[rng.Next(pool.Count)];
    }

    private static (Trick, bool) WeightedPickWithContext(
        List<(Trick Trick, bool StrongFoot)> candidates,
        Trick prev,
        bool isLastSlot,
        Random rng)
    {
        var weights = candidates.Select(s =>
        {
            // Heavy penalty for consecutive high-rev tricks — rare but possible
            if (prev.Revolution >= 3 && s.Trick.Revolution >= 3)
                return 1;

            int w = s.Trick.CommonLevel;
            if (prev.CrossOver && s.Trick.CrossOver) w += 3;
            if (isLastSlot && s.Trick.CrossOver) w += 2;
            return w;
        }).ToArray();

        var total = weights.Sum();
        var roll = rng.Next(1, total + 1);
        int acc = 0;
        for (int i = 0; i < candidates.Count; i++)
        {
            acc += weights[i];
            if (roll <= acc) return candidates[i];
        }
        return candidates[^1];
    }
}
