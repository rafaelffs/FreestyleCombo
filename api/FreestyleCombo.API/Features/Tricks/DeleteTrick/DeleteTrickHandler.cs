using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Tricks.DeleteTrick;

public class DeleteTrickHandler : IRequestHandler<DeleteTrickCommand>
{
    private readonly ITrickRepository _repo;

    public DeleteTrickHandler(ITrickRepository repo) => _repo = repo;

    public async Task Handle(DeleteTrickCommand request, CancellationToken cancellationToken)
    {
        await _repo.DeleteAsync(request.Id, cancellationToken);
    }
}
