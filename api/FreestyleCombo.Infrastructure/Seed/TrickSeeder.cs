using FreestyleCombo.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using FreestyleCombo.Core.Entities;

namespace FreestyleCombo.Infrastructure.Seed;

public static class TrickSeeder
{
    public static async Task SeedAsync(AppDbContext db, CancellationToken ct = default)
    {
        if (await db.Tricks.AnyAsync(ct))
            return;

        var tricks = new List<Trick>
        {
            new() { Id = Guid.NewGuid(), Name = "Crossover",                                                   Abbreviation = "CO",           Revolution = 1.0m,  CrossOver = true,  Knee = false, Difficulty = 1,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Reverse Crossover",                                           Abbreviation = "RevCO",        Revolution = 1.0m,  CrossOver = true,  Knee = false, Difficulty = 1,  CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Mitch Around the World",                                      Abbreviation = "MATW",         Revolution = 1.5m,  CrossOver = true,  Knee = false, Difficulty = 2,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Touzani Around the World",                                    Abbreviation = "TATW",         Revolution = 1.5m,  CrossOver = true,  Knee = false, Difficulty = 2,  CommonLevel = 9 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Touzani Around the World",                          Abbreviation = "ATATW",        Revolution = 1.5m,  CrossOver = true,  Knee = false, Difficulty = 2,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Mitch Around the World",                            Abbreviation = "AMATW",        Revolution = 1.5m,  CrossOver = true,  Knee = false, Difficulty = 2,  CommonLevel = 9 },
            new() { Id = Guid.NewGuid(), Name = "Homie Mitch Around the World",                                Abbreviation = "HMATW",        Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 2,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Homie Touzani Around the World",                              Abbreviation = "HTATW",        Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 2,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Homie Jay Around the World",                                  Abbreviation = "HJATW",        Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 2,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Reverse Homie Jay Around the World",                          Abbreviation = "RHJATW",       Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 3,  CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Homie Mitch Around the World",                      Abbreviation = "AHMATW",       Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 4,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Homie Touzani Around the World",                    Abbreviation = "AHTATW",       Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 4,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Reverse Homie Jay Around the World",                Abbreviation = "ARHJATW",      Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 5,  CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Homie Jay Around the World",                        Abbreviation = "AHJATW",       Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 5,  CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Lemmens Around the World Inside",                             Abbreviation = "LATW IN",      Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 2,  CommonLevel = 9 },
            new() { Id = Guid.NewGuid(), Name = "Lemmens Around the World Outside",                            Abbreviation = "LATW OUT",     Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 2,  CommonLevel = 9 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Lemmens Around the World Inside",                   Abbreviation = "ALATW IN",     Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 4,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Lemmens Around the World Outside",                  Abbreviation = "ALATW OUT",    Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 6,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Inside-Inside",                                      Abbreviation = "MAG IN-IN",    Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 2,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Outside-Outside",                                    Abbreviation = "MAG OUT-OUT",  Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 4,  CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Inside-Outside",                                     Abbreviation = "MAG IN-OUT",   Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 5,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Outside-Inside",                                     Abbreviation = "MAG OUT-IN",   Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 2,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Inside-Inside",                            Abbreviation = "AMAG IN-IN",   Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 4,  CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Outside-Outside",                          Abbreviation = "AMAG OUT-OUT", Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 5,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Inside-Outside",                           Abbreviation = "AMAG IN-OUT",  Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 5,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Outside-Inside",                           Abbreviation = "AMAG OUT-IN",  Revolution = 2.0m,  CrossOver = false, Knee = false, Difficulty = 5,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Palle Trick",                                                 Abbreviation = "PalleTrick",   Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 3,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Reverse Palle Trick",                                         Abbreviation = "RPalleTrick",  Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 4,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Skora Around the World",                                      Abbreviation = "SATW",         Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Reverse Skora Around the World",                              Abbreviation = "RSATW",        Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Reverse Homie Jay Touzani Around the World",                  Abbreviation = "RHJTATW",      Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Lemmens Mitch Around the World",                              Abbreviation = "LMATW",        Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 3,  CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Lemmens Touzani Around the World",                            Abbreviation = "LTATW",        Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 3,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Lemmens Mitch Around the World",                    Abbreviation = "ALMATW",       Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 5,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Lemmens Touzani Around the World",                  Abbreviation = "ALTATW",       Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Mitch Inside-Inside",                                Abbreviation = "MAGM IN-IN",   Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 4,  CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Touzani Outside-Outside",                            Abbreviation = "MAGT OUT-OUT", Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 4,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Touzani Inside-Outside",                             Abbreviation = "MAGT IN-OUT",  Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 5,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Mitch Outside-Inside",                               Abbreviation = "MAGM OUT-IN",  Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 4,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Mitch Inside-Inside",                      Abbreviation = "AMAGM IN-IN",  Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Touzani Outside-Outside",                  Abbreviation = "AMAGT OUT-OUT",Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Touzani Inside-Outside",                   Abbreviation = "AMAGT IN-OUT", Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Mitch Outside-Inside",                     Abbreviation = "AMAGM OUT-IN", Revolution = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Eldo Around the World",                                       Abbreviation = "EATW",         Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 7,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Skala Around the World",                                      Abbreviation = "SKATW",        Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 7,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Palle Around the World Inside",                               Abbreviation = "PATW IN",      Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 6,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Palle Around the World Outside",                              Abbreviation = "PATW OUT",     Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Homie Mitch Lemmens Around the World",                        Abbreviation = "HMLATW",       Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Homie Touzani Lemmens Around the World",                      Abbreviation = "HTLATW",       Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 7,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Skora Move",                                                  Abbreviation = "SK MOVE",      Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 7,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "MP Around the World",                                         Abbreviation = "MPATW",        Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Syzmo Around the World",                                      Abbreviation = "SZATW",        Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 7,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Japa Around the World",                                       Abbreviation = "JAPAATW",      Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 7,  CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Zegan Around the World",                                      Abbreviation = "ZATW",         Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Crazy Feet Around the World",                                 Abbreviation = "CFATW",        Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Adrian Krogster Move Around the World",                       Abbreviation = "AK MOVE",      Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "MP Trick",                                                    Abbreviation = "MP TRICK",     Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Homie Mitch Lemmens Around the World",              Abbreviation = "AHMLATW",      Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 9,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Homie Touzani Lemmens Around the World",            Abbreviation = "AHTLATW",      Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 9,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Skala Around the World",                            Abbreviation = "ASKATW",       Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 9,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Eldo Around the World",                             Abbreviation = "AEATW",        Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 9,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Palle Around the World",                            Abbreviation = "APATW",        Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Iago Around the World",                                       Abbreviation = "IATW",         Revolution = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Eldo Mitch Around the World",                                 Abbreviation = "EMATW",        Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Skala Mitch Around the World",                                Abbreviation = "SKMATW",       Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Palle Mitch Around the World Inside",                         Abbreviation = "PMATW",        Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 7,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Palle Touzani Around the World Outside",                      Abbreviation = "PTATW",        Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 9,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Homie Mitch Lemmens Mitch Around the World",                  Abbreviation = "HMLMATW",      Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 10, CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Homie Touzani Lemmens Mitch Around the World",                Abbreviation = "HTLMATW",      Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 10, CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Skora Move Mitch",                                            Abbreviation = "SK MOVE M",    Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Syzmo Mitch Around the World",                                Abbreviation = "SZMATW",       Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Japa Mitch Around the World",                                 Abbreviation = "JAPAMATW",     Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Zegan Mitch Around the World",                                Abbreviation = "ZMATW",        Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 9,  CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Crazy Feet Mitch Around the World",                           Abbreviation = "CFMATW",       Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 10, CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Adrian Krogster Move Mitch Around the World",                 Abbreviation = "AK MOVE M",    Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "MP Trick Mitch",                                              Abbreviation = "MP TRICK M",   Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "MP Mitch Around the World",                                   Abbreviation = "MPMATW",       Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Homie Mitch Lemmens Mitch Around the World",        Abbreviation = "AHMLMATW",     Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 10, CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Homie Touzani Lemmens Mitch Around the World",      Abbreviation = "AHTLMATW",     Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 10, CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Skala Mitch Around the World",                      Abbreviation = "ASKMATW",      Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 10, CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Eldo Mitch Around the World",                       Abbreviation = "AEMATW",       Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 9,  CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Palle Mitch Around the World",                      Abbreviation = "APMATW",       Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Iago Mitch Around the World",                                 Abbreviation = "IMATW",        Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 9,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Palle Touzani Around the World",                    Abbreviation = "APTATW",       Revolution = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 10, CommonLevel = 2 },
        };

        await db.Tricks.AddRangeAsync(tricks, ct);
        await db.SaveChangesAsync(ct);
    }

    public static async Task SeedTransitionTricksAsync(AppDbContext db, CancellationToken ct = default)
    {
        if (await db.Tricks.AnyAsync(t => t.IsTransition, ct))
            return;

        db.Tricks.Add(new Trick
        {
            Id = Guid.NewGuid(),
            Name = "Combo",
            Abbreviation = "combo",
            CrossOver = false,
            Knee = false,
            Revolution = 1.0m,
            Difficulty = 1,
            CommonLevel = 1,
            IsTransition = true
        });

        await db.SaveChangesAsync(ct);
    }
}
