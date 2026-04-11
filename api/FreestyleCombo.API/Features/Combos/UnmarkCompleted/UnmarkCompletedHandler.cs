using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.UnmarkCompleted;

public class UnmarkCompletedHandler : IRequestHandler<UnmarkCompletedCommand>
{
    private readonly IUserComboCompletionRepository _repo;

    public UnmarkCompletedHandler(IUserComboCompletionRepository repo) => _repo = repo;

    public async Task Handle(UnmarkCompletedCommand request, CancellationToken cancellationToken) =>
        await _repo.RemoveAsync(request.UserId, request.ComboId, cancellationToken);
}
