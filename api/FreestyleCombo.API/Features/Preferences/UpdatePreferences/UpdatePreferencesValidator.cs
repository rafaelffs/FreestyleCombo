using FluentValidation;

namespace FreestyleCombo.API.Features.Preferences.UpdatePreferences;

public class UpdatePreferencesValidator : AbstractValidator<UpdatePreferencesCommand>
{
    public UpdatePreferencesValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        RuleFor(x => x.MaxDifficulty).InclusiveBetween(1, 10).When(x => x.MaxDifficulty.HasValue);
        RuleFor(x => x.ComboLength).InclusiveBetween(1, 100).When(x => x.ComboLength.HasValue);
        RuleFor(x => x.StrongFootPercentage).InclusiveBetween(0, 100).When(x => x.StrongFootPercentage.HasValue);
        RuleFor(x => x.NoTouchPercentage).InclusiveBetween(0, 100).When(x => x.NoTouchPercentage.HasValue);
        RuleFor(x => x.MaxConsecutiveNoTouch).InclusiveBetween(0, 30).When(x => x.MaxConsecutiveNoTouch.HasValue);
        RuleForEach(x => x.AllowedRevolutions).InclusiveBetween(0.5m, 4m);
        RuleFor(x => x.MaxHighRevolutionTricks).InclusiveBetween(1, 15).When(x => x.MaxHighRevolutionTricks.HasValue);
    }
}
