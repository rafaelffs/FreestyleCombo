using MediatR;

namespace FreestyleCombo.API.Features.Combos.UnmarkCompleted;

public record UnmarkCompletedCommand(Guid ComboId, Guid UserId) : IRequest;
