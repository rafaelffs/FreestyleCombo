using FreestyleCombo.Core.Interfaces;
using MediatR;

namespace FreestyleCombo.API.Features.Tricks.UpdateTrick;

public class UpdateTrickHandler : IRequestHandler<UpdateTrickCommand>
{
    private readonly ITrickRepository _repo;

    public UpdateTrickHandler(ITrickRepository repo) => _repo = repo;

    public async Task Handle(UpdateTrickCommand request, CancellationToken cancellationToken)
    {
        var trick = await _repo.GetByIdAsync(request.Id, cancellationToken)
            ?? throw new KeyNotFoundException("Trick not found.");

        trick.Name = request.Name;
        trick.Abbreviation = request.Abbreviation;
        trick.CrossOver = request.CrossOver;
        trick.Knee = request.Knee;
        trick.Revolution = request.Revolution;
        trick.Difficulty = request.Difficulty;
        trick.CommonLevel = request.CommonLevel;

        await _repo.UpdateAsync(trick, cancellationToken);
    }
}
