using MediatR;

namespace FreestyleCombo.API.Features.Combos.DeleteCombo;

public record DeleteComboCommand(Guid ComboId) : IRequest;
