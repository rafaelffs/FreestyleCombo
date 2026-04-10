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
            new() { Id = Guid.NewGuid(), Name = "Crossover",                                                   Abbreviation = "CO",           Motion = 1.0m,  CrossOver = true,  Knee = false, Difficulty = 1,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Reverse Crossover",                                           Abbreviation = "RevCO",        Motion = 1.0m,  CrossOver = true,  Knee = false, Difficulty = 1,  CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Mitch Around the World",                                      Abbreviation = "MATW",         Motion = 1.5m,  CrossOver = true,  Knee = false, Difficulty = 2,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Touzani Around the World",                                    Abbreviation = "TATW",         Motion = 1.5m,  CrossOver = true,  Knee = false, Difficulty = 2,  CommonLevel = 9 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Touzani Around the World",                          Abbreviation = "ATATW",        Motion = 1.5m,  CrossOver = true,  Knee = false, Difficulty = 2,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Mitch Around the World",                            Abbreviation = "AMATW",        Motion = 1.5m,  CrossOver = true,  Knee = false, Difficulty = 2,  CommonLevel = 9 },
            new() { Id = Guid.NewGuid(), Name = "Homie Mitch Around the World",                                Abbreviation = "HMATW",        Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 2,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Homie Touzani Around the World",                              Abbreviation = "HTATW",        Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 2,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Homie Jay Around the World",                                  Abbreviation = "HJATW",        Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 2,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Reverse Homie Jay Around the World",                          Abbreviation = "RHJATW",       Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 3,  CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Homie Mitch Around the World",                      Abbreviation = "AHMATW",       Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 4,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Homie Touzani Around the World",                    Abbreviation = "AHTATW",       Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 4,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Reverse Homie Jay Around the World",                Abbreviation = "ARHJATW",      Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 5,  CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Homie Jay Around the World",                        Abbreviation = "AHJATW",       Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 5,  CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Lemmens Around the World Inside",                             Abbreviation = "LATW IN",      Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 2,  CommonLevel = 9 },
            new() { Id = Guid.NewGuid(), Name = "Lemmens Around the World Outside",                            Abbreviation = "LATW OUT",     Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 2,  CommonLevel = 9 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Lemmens Around the World Inside",                   Abbreviation = "ALATW IN",     Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 4,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Lemmens Around the World Outside",                  Abbreviation = "ALATW OUT",    Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 6,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Inside-Inside",                                      Abbreviation = "MAG IN-IN",    Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 2,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Outside-Outside",                                    Abbreviation = "MAG OUT-OUT",  Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 4,  CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Inside-Outside",                                     Abbreviation = "MAG IN-OUT",   Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 5,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Outside-Inside",                                     Abbreviation = "MAG OUT-IN",   Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 2,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Inside-Inside",                            Abbreviation = "AMAG IN-IN",   Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 4,  CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Outside-Outside",                          Abbreviation = "AMAG OUT-OUT", Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 5,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Inside-Outside",                           Abbreviation = "AMAG IN-OUT",  Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 5,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Outside-Inside",                           Abbreviation = "AMAG OUT-IN",  Motion = 2.0m,  CrossOver = false, Knee = false, Difficulty = 5,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Palle Trick",                                                 Abbreviation = "PalleTrick",   Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 3,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Reverse Palle Trick",                                         Abbreviation = "RPalleTrick",  Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 4,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Skora Around the World",                                      Abbreviation = "SATW",         Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Reverse Skora Around the World",                              Abbreviation = "RSATW",        Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Reverse Homie Jay Touzani Around the World",                  Abbreviation = "RHJTATW",      Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Lemmens Mitch Around the World",                              Abbreviation = "LMATW",        Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 3,  CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Lemmens Touzani Around the World",                            Abbreviation = "LTATW",        Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 3,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Lemmens Mitch Around the World",                    Abbreviation = "ALMATW",       Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 5,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Lemmens Touzani Around the World",                  Abbreviation = "ALTATW",       Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Mitch Inside-Inside",                                Abbreviation = "MAGM IN-IN",   Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 4,  CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Touzani Outside-Outside",                            Abbreviation = "MAGT OUT-OUT", Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 4,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Touzani Inside-Outside",                             Abbreviation = "MAGT IN-OUT",  Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 5,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Magellan Mitch Outside-Inside",                               Abbreviation = "MAGM OUT-IN",  Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 4,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Mitch Inside-Inside",                      Abbreviation = "AMAGM IN-IN",  Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Touzani Outside-Outside",                  Abbreviation = "AMAGT OUT-OUT",Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Touzani Inside-Outside",                   Abbreviation = "AMAGT IN-OUT", Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Magellan Mitch Outside-Inside",                     Abbreviation = "AMAGM OUT-IN", Motion = 2.5m,  CrossOver = true,  Knee = false, Difficulty = 6,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Eldo Around the World",                                       Abbreviation = "EATW",         Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 7,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Skala Around the World",                                      Abbreviation = "SKATW",        Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 7,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Palle Around the World Inside",                               Abbreviation = "PATW IN",      Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 6,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Palle Around the World Outside",                              Abbreviation = "PATW OUT",     Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Homie Mitch Lemmens Around the World",                        Abbreviation = "HMLATW",       Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Homie Touzani Lemmens Around the World",                      Abbreviation = "HTLATW",       Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 7,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Skora Move",                                                  Abbreviation = "SK MOVE",      Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 7,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "MP Around the World",                                         Abbreviation = "MPATW",        Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Syzmo Around the World",                                      Abbreviation = "SZATW",        Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 7,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Japa Around the World",                                       Abbreviation = "JAPAATW",      Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 7,  CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Zegan Around the World",                                      Abbreviation = "ZATW",         Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Crazy Feet Around the World",                                 Abbreviation = "CFATW",        Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Adrian Krogster Move Around the World",                       Abbreviation = "AK MOVE",      Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "MP Trick",                                                    Abbreviation = "MP TRICK",     Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Homie Mitch Lemmens Around the World",              Abbreviation = "AHMLATW",      Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 9,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Homie Touzani Lemmens Around the World",            Abbreviation = "AHTLATW",      Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 9,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Skala Around the World",                            Abbreviation = "ASKATW",       Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 9,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Eldo Around the World",                             Abbreviation = "AEATW",        Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 9,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Palle Around the World",                            Abbreviation = "APATW",        Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Iago Around the World",                                       Abbreviation = "IATW",         Motion = 3.0m,  CrossOver = false, Knee = false, Difficulty = 8,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Eldo Mitch Around the World",                                 Abbreviation = "EMATW",        Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Skala Mitch Around the World",                                Abbreviation = "SKMATW",       Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Palle Mitch Around the World Inside",                         Abbreviation = "PMATW",        Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 7,  CommonLevel = 8 },
            new() { Id = Guid.NewGuid(), Name = "Palle Touzani Around the World Outside",                      Abbreviation = "PTATW",        Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 9,  CommonLevel = 6 },
            new() { Id = Guid.NewGuid(), Name = "Homie Mitch Lemmens Mitch Around the World",                  Abbreviation = "HMLMATW",      Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 10, CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Homie Touzani Lemmens Mitch Around the World",                Abbreviation = "HTLMATW",      Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 10, CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Skora Move Mitch",                                            Abbreviation = "SK MOVE M",    Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Syzmo Mitch Around the World",                                Abbreviation = "SZMATW",       Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Japa Mitch Around the World",                                 Abbreviation = "JAPAMATW",     Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Zegan Mitch Around the World",                                Abbreviation = "ZMATW",        Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 9,  CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Crazy Feet Mitch Around the World",                           Abbreviation = "CFMATW",       Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 10, CommonLevel = 1 },
            new() { Id = Guid.NewGuid(), Name = "Adrian Krogster Move Mitch Around the World",                 Abbreviation = "AK MOVE M",    Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "MP Trick Mitch",                                              Abbreviation = "MP TRICK M",   Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "MP Mitch Around the World",                                   Abbreviation = "MPMATW",       Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Homie Mitch Lemmens Mitch Around the World",        Abbreviation = "AHMLMATW",     Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 10, CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Homie Touzani Lemmens Mitch Around the World",      Abbreviation = "AHTLMATW",     Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 10, CommonLevel = 4 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Skala Mitch Around the World",                      Abbreviation = "ASKMATW",      Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 10, CommonLevel = 2 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Eldo Mitch Around the World",                       Abbreviation = "AEMATW",       Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 9,  CommonLevel = 5 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Palle Mitch Around the World",                      Abbreviation = "APMATW",       Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 8,  CommonLevel = 7 },
            new() { Id = Guid.NewGuid(), Name = "Iago Mitch Around the World",                                 Abbreviation = "IMATW",        Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 9,  CommonLevel = 3 },
            new() { Id = Guid.NewGuid(), Name = "Alternate Palle Touzani Around the World",                    Abbreviation = "APTATW",       Motion = 3.5m,  CrossOver = true,  Knee = false, Difficulty = 10, CommonLevel = 2 },
        };

        await db.Tricks.AddRangeAsync(tricks, ct);
        await db.SaveChangesAsync(ct);
    }
}
