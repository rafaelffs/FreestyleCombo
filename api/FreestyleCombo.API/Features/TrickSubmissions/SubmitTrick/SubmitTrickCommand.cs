using MediatR;

namespace FreestyleCombo.API.Features.TrickSubmissions.SubmitTrick;

public record SubmitTrickCommand(
    string Name,
    string Abbreviation,
    bool CrossOver,
    bool Knee,
    decimal Motion,
    int Difficulty,
    int CommonLevel
) : IRequest<Guid>;

