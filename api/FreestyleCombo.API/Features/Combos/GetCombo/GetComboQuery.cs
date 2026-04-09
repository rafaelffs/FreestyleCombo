using MediatR;

namespace FreestyleCombo.API.Features.Combos.GetCombo;

public record GetComboQuery(Guid ComboId, Guid? RequestingUserId) : IRequest<ComboDetailDto>;
