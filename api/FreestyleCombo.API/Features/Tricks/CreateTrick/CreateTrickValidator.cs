using FluentValidation;

namespace FreestyleCombo.API.Features.Tricks.CreateTrick;

public class CreateTrickValidator : AbstractValidator<CreateTrickCommand>
{
    public CreateTrickValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Abbreviation).NotEmpty().MaximumLength(20);
        RuleFor(x => x.Revolution)
            .InclusiveBetween(0.5m, 4m)
            .Must(r => r * 2 % 1 == 0m).WithMessage("Revolution must be in increments of 0.5.");
        RuleFor(x => x.Difficulty).InclusiveBetween(1, 10);
        RuleFor(x => x.CommonLevel).InclusiveBetween(1, 10);
    }
}
