using MediatR;

namespace FreestyleCombo.API.Features.Combos.SetPersonalReusable;

public record SetPersonalReusableCommand(Guid ComboId, Guid UserId, bool IsPersonalReusable) : IRequest;
