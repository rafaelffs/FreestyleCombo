using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.MarkCompleted;

public class MarkCompletedHandler : IRequestHandler<MarkCompletedCommand>
{
    private readonly IUserComboCompletionRepository _repo;

    public MarkCompletedHandler(IUserComboCompletionRepository repo) => _repo = repo;

    public async Task Handle(MarkCompletedCommand request, CancellationToken cancellationToken) =>
        await _repo.AddAsync(request.UserId, request.ComboId, cancellationToken);
}
