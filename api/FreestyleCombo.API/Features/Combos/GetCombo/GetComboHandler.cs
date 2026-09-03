using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Combos.GetCombo;

public class GetComboHandler : IRequestHandler<GetComboQuery, ComboDetailDto>
{
    private readonly IComboRepository _repo;
    private readonly IUserFavouriteRepository _favRepo;
    private readonly IUserComboCompletionRepository _completionRepo;
    private readonly IUserPersonalReusableComboRepository _personalReusableRepo;

    public GetComboHandler(
        IComboRepository repo,
        IUserFavouriteRepository favRepo,
        IUserComboCompletionRepository completionRepo,
        IUserPersonalReusableComboRepository personalReusableRepo)
    {
        _repo = repo;
        _favRepo = favRepo;
        _completionRepo = completionRepo;
        _personalReusableRepo = personalReusableRepo;
    }

    public async Task<ComboDetailDto> Handle(GetComboQuery request, CancellationToken cancellationToken)
    {
        // Deliberately no visibility/ownership gate: this is also the
        // "open a shared link" path — anyone holding a combo's id can view
        // it regardless of Visibility (Private/PendingReview/Public), same
        // "anyone with the link can view" trust model as e.g. Google Docs
        // or Figma share links. GUIDs aren't enumerable, and the combo
        // listing endpoints (GetPublicCombos/GetMyCombos) still filter by
        // Visibility, so a non-public combo is still only reachable if its
        // id was deliberately shared, not discoverable by browsing.
        var combo = await _repo.GetByIdAsync(request.ComboId, cancellationToken)
            ?? throw new KeyNotFoundException("Combo not found.");

        var isFavourited = request.RequestingUserId.HasValue
            && await _favRepo.ExistsAsync(request.RequestingUserId.Value, combo.Id, cancellationToken);

        var isCompleted = request.RequestingUserId.HasValue
            && await _completionRepo.ExistsAsync(request.RequestingUserId.Value, combo.Id, cancellationToken);

        var isPersonalReusable = request.RequestingUserId.HasValue
            && await _personalReusableRepo.ExistsAsync(request.RequestingUserId.Value, combo.Id, cancellationToken);

        var counts = await _completionRepo.GetCompletionCountsAsync([combo.Id], cancellationToken);
        var completionCount = counts.GetValueOrDefault(combo.Id, 0);

        return ComboDetailMapper.Map(combo, isFavourited, isCompleted, isPersonalReusable, completionCount);
    }
}
