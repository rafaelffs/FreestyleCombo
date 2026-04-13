using FluentValidation;

namespace FreestyleCombo.API.Features.Preferences.CreatePreference;

public class CreatePreferenceValidator : AbstractValidator<CreatePreferenceCommand>
{
    public CreatePreferenceValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        RuleFor(x => x.MaxDifficulty).InclusiveBetween(1, 10);
        RuleFor(x => x.ComboLength).InclusiveBetween(1, 100);
        RuleFor(x => x.StrongFootPercentage).InclusiveBetween(0, 100);
        RuleFor(x => x.NoTouchPercentage).InclusiveBetween(0, 100);
        RuleFor(x => x.MaxConsecutiveNoTouch).InclusiveBetween(0, 30);
        RuleForEach(x => x.AllowedRevolutions).InclusiveBetween(0.5m, 4m);
    }
}
