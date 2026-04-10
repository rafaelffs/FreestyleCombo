using FreestyleCombo.API.Features.TrickSubmissions;
using MediatR;

namespace FreestyleCombo.API.Features.TrickSubmissions.GetMySubmissions;

public record GetMySubmissionsQuery : IRequest<List<TrickSubmissionDto>>;
