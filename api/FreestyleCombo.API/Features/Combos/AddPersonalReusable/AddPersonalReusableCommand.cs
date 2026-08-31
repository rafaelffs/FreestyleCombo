using MediatR;

namespace FreestyleCombo.API.Features.Combos.AddPersonalReusable;

public record AddPersonalReusableCommand(Guid ComboId, Guid UserId) : IRequest;
