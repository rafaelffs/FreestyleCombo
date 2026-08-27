using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Tricks.GetTrickById;

public class GetTrickByIdHandler : IRequestHandler<GetTrickByIdQuery, TrickDetailDto>
{
    private readonly ITrickRepository _repo;

    public GetTrickByIdHandler(ITrickRepository repo) => _repo = repo;

    public async Task<TrickDetailDto> Handle(GetTrickByIdQuery request, CancellationToken cancellationToken)
    {
        var trick = await _repo.GetByIdAsync(request.Id, cancellationToken)
            ?? throw new KeyNotFoundException("Trick not found.");

        return new TrickDetailDto
        {
            Id = trick.Id,
            Name = trick.Name,
            Abbreviation = trick.Abbreviation,
            CrossOver = trick.CrossOver,
            Knee = trick.Knee,
            Revolution = trick.Revolution,
            Difficulty = trick.Difficulty,
            CommonLevel = trick.CommonLevel,
            IsTransition = trick.IsTransition,
            CreatedBy = trick.CreatedBy,
            DateCreated = trick.DateCreated,
            Notes = trick.Notes
        };
    }
}
