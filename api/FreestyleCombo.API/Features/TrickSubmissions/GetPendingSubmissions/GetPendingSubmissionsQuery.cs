using FreestyleCombo.API.Features.TrickSubmissions;
using MediatR;

namespace FreestyleCombo.API.Features.TrickSubmissions.GetPendingSubmissions;

public record GetPendingSubmissionsQuery : IRequest<List<TrickSubmissionDto>>;
