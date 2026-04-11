using MediatR;

namespace FreestyleCombo.API.Features.Combos.ApproveComboVisibility;

public record ApproveComboVisibilityCommand(Guid ComboId) : IRequest;
