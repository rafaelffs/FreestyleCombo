using FluentValidation;

namespace FreestyleCombo.API.Features.Preferences.UpdatePreferences;

public class UpdatePreferencesValidator : AbstractValidator<UpdatePreferencesCommand>
{
    public UpdatePreferencesValidator()
    {
        RuleFor(x => x.MaxDifficulty).InclusiveBetween(1, 10).When(x => x.MaxDifficulty.HasValue);
        RuleFor(x => x.ComboLength).InclusiveBetween(1, 20).When(x => x.ComboLength.HasValue);
        RuleFor(x => x.StrongFootPercentage).InclusiveBetween(0, 100).When(x => x.StrongFootPercentage.HasValue);
        RuleFor(x => x.NoTouchPercentage).InclusiveBetween(0, 100).When(x => x.NoTouchPercentage.HasValue);
        RuleFor(x => x.MaxConsecutiveNoTouch).GreaterThanOrEqualTo(0).When(x => x.MaxConsecutiveNoTouch.HasValue);
    }
}
