using MediatR;
using FreestyleCombo.API.Features.Combos.GenerateCombo;

namespace FreestyleCombo.API.Features.Combos.BuildCombo;

public record BuildComboCommand(
    List<BuildComboTrickItem> Tricks,
    bool IsPublic = false,
    string? Name = null
) : IRequest<GenerateComboResponse>;

public record BuildComboTrickItem(
    Guid TrickId,
    int Position,
    bool StrongFoot,
    bool NoTouch
);
