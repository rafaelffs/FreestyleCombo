using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Admin;

public record GetPendingApprovalsCountQuery : IRequest<int>;

public class GetPendingApprovalsCountHandler : IRequestHandler<GetPendingApprovalsCountQuery, int>
{
    private readonly IComboRepository _comboRepo;
    private readonly ITrickSubmissionRepository _submissionRepo;

    public GetPendingApprovalsCountHandler(IComboRepository comboRepo, ITrickSubmissionRepository submissionRepo)
    {
        _comboRepo = comboRepo;
        _submissionRepo = submissionRepo;
    }

    public async Task<int> Handle(GetPendingApprovalsCountQuery request, CancellationToken cancellationToken)
    {
        var combos = await _comboRepo.GetPendingReviewCountAsync(cancellationToken);
        var tricks = await _submissionRepo.GetPendingCountAsync(cancellationToken);
        return combos + tricks;
    }
}
