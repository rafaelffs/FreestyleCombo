using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.RemovePersonalReusable;

public class RemovePersonalReusableHandler : IRequestHandler<RemovePersonalReusableCommand>
{
    private readonly IUserPersonalReusableComboRepository _personalReusableRepo;

    public RemovePersonalReusableHandler(IUserPersonalReusableComboRepository personalReusableRepo) => _personalReusableRepo = personalReusableRepo;

    public async Task Handle(RemovePersonalReusableCommand request, CancellationToken cancellationToken) =>
        await _personalReusableRepo.RemoveAsync(request.UserId, request.ComboId, cancellationToken);
}
