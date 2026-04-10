using FluentValidation;

namespace FreestyleCombo.API.Features.Combos.GenerateCombo;

public class GenerateComboValidator : AbstractValidator<GenerateComboCommand>
{
    public GenerateComboValidator()
    {
        When(x => x.Overrides != null, () =>
        {
            RuleFor(x => x.Overrides!.MaxDifficulty).InclusiveBetween(1, 10).When(x => x.Overrides!.MaxDifficulty.HasValue);
            RuleFor(x => x.Overrides!.ComboLength).InclusiveBetween(1, 100).When(x => x.Overrides!.ComboLength.HasValue);
            RuleFor(x => x.Overrides!.StrongFootPercentage).InclusiveBetween(0, 100).When(x => x.Overrides!.StrongFootPercentage.HasValue);
            RuleFor(x => x.Overrides!.NoTouchPercentage).InclusiveBetween(0, 100).When(x => x.Overrides!.NoTouchPercentage.HasValue);
            RuleFor(x => x.Overrides!.MaxConsecutiveNoTouch).InclusiveBetween(0, 30).When(x => x.Overrides!.MaxConsecutiveNoTouch.HasValue);
        });
    }
}
