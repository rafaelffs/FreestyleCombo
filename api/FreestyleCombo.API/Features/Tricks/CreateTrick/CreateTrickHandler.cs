using FreestyleCombo.Core.Entities;
using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Tricks.CreateTrick;

public class CreateTrickHandler : IRequestHandler<CreateTrickCommand, Guid>
{
    private readonly ITrickRepository _repo;

    public CreateTrickHandler(ITrickRepository repo) => _repo = repo;

    public async Task<Guid> Handle(CreateTrickCommand request, CancellationToken cancellationToken)
    {
        var trick = new Trick
        {
            Id = Guid.NewGuid(),
            Name = request.Name,
            Abbreviation = request.Abbreviation,
            CrossOver = request.CrossOver,
            Knee = request.Knee,
            Revolution = request.Revolution,
            Difficulty = request.Difficulty,
            CommonLevel = request.CommonLevel
        };

        await _repo.AddAsync(trick, cancellationToken);
        return trick.Id;
    }
}
