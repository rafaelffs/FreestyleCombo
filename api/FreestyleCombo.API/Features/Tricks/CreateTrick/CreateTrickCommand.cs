using MediatR;

namespace FreestyleCombo.API.Features.Tricks.CreateTrick;

public record CreateTrickCommand(
    string Name,
    string Abbreviation,
    bool CrossOver,
    bool Knee,
    decimal Revolution,
    int Difficulty,
    int CommonLevel,
    string? CreatedBy,
    DateOnly? DateCreated,
    string? Notes
) : IRequest<Guid>;
