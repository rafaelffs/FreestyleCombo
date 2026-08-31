using MediatR;

namespace FreestyleCombo.API.Features.Combos.RemovePersonalReusable;

public record RemovePersonalReusableCommand(Guid ComboId, Guid UserId) : IRequest;
