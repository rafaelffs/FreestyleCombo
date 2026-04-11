using FluentValidation;

namespace FreestyleCombo.API.Features.Tricks.UpdateTrick;

public class UpdateTrickValidator : AbstractValidator<UpdateTrickCommand>
{
    public UpdateTrickValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Abbreviation).NotEmpty().MaximumLength(20);
        RuleFor(x => x.Revolution).InclusiveBetween(0.5m, 10m);
        RuleFor(x => x.Difficulty).InclusiveBetween(1, 10);
        RuleFor(x => x.CommonLevel).InclusiveBetween(1, 10);
    }
}
