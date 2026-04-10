using MediatR;

namespace FreestyleCombo.API.Features.Tricks.UpdateTrick;

public record UpdateTrickCommand(
    Guid Id,
    string Name,
    string Abbreviation,
    bool CrossOver,
    bool Knee,
    decimal Motion,
    int Difficulty,
    int CommonLevel
) : IRequest;
