using MediatR;

namespace FreestyleCombo.API.Features.TrickSubmissions.RejectSubmission;

public record RejectSubmissionCommand(Guid SubmissionId) : IRequest;
