using MediatR;

namespace FreestyleCombo.API.Features.TrickSubmissions.ApproveSubmission;

public record ApproveSubmissionCommand(Guid SubmissionId) : IRequest;
