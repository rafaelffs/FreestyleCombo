using MediatR;

namespace FreestyleCombo.API.Features.Combos.MarkCompleted;

public record MarkCompletedCommand(Guid ComboId, Guid UserId) : IRequest;
