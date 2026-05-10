using FreestyleCombo.API.Features.Combos.GenerateCombo;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.SetReusable;

public record SetReusableCommand(Guid ComboId, bool IsReusable) : IRequest<GenerateComboResponse>;
