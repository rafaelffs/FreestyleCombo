using FluentValidation;

namespace FreestyleCombo.API.Features.TrickSubmissions.SubmitTrick;

public class SubmitTrickValidator : AbstractValidator<SubmitTrickCommand>
{
    public SubmitTrickValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Abbreviation).NotEmpty().MaximumLength(20);
        RuleFor(x => x.Revolution).InclusiveBetween(0.5m, 4m);
        RuleFor(x => x.Difficulty).InclusiveBetween(1, 10);
        RuleFor(x => x.CommonLevel).InclusiveBetween(1, 10);
    }
}
