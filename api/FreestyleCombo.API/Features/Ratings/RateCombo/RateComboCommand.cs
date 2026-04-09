using MediatR;

namespace FreestyleCombo.API.Features.Ratings.RateCombo;

public record RateComboCommand(Guid ComboId, Guid UserId, int Score) : IRequest<Guid>;
