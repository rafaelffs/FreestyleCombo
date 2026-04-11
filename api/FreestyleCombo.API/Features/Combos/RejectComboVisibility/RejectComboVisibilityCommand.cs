using MediatR;

namespace FreestyleCombo.API.Features.Combos.RejectComboVisibility;

public record RejectComboVisibilityCommand(Guid ComboId) : IRequest;
