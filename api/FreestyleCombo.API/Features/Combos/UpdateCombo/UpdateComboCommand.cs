using FreestyleCombo.API.Features.Combos.BuildCombo;
using FreestyleCombo.API.Features.Combos.GenerateCombo;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.UpdateCombo;

public record UpdateComboCommand(
    Guid ComboId,
    string? Name,
    List<BuildComboTrickItem>? Tricks
) : IRequest<GenerateComboResponse>;
