using MediatR;

namespace FreestyleCombo.API.Features.Combos.UpdateVisibility;

public record UpdateVisibilityCommand(Guid ComboId, Guid UserId, bool IsPublic) : IRequest;
