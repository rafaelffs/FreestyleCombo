using MediatR;

namespace FreestyleCombo.API.Features.Tricks.GetTricks;

public record GetTricksQuery(bool? CrossOver, bool? Knee, int? MaxDifficulty) : IRequest<List<TrickDto>>;
