using FreestyleCombo.Core.Entities;

namespace FreestyleCombo.API.Features.TrickSubmissions;

public record TrickSubmissionDto(
    Guid Id,
    string Name,
    string Abbreviation,
    bool CrossOver,
    bool Knee,
    decimal Motion,
    int Difficulty,
    int CommonLevel,
    string Status,
    DateTime SubmittedAt,
    string SubmittedByUserName,
    DateTime? ReviewedAt
)
{
    public static TrickSubmissionDto From(TrickSubmission s) => new(
        s.Id,
        s.Name,
        s.Abbreviation,
        s.CrossOver,
        s.Knee,
        s.Motion,
        s.Difficulty,
        s.CommonLevel,
        s.Status.ToString(),
        s.SubmittedAt,
        s.SubmittedBy?.UserName ?? string.Empty,
        s.ReviewedAt
    );
}
