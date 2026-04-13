using FluentValidation;

namespace FreestyleCombo.API.Features.Combos.PreviewCombo;

public class PreviewComboValidator : AbstractValidator<PreviewComboCommand>
{
    public PreviewComboValidator()
    {
        When(x => x.Overrides?.AllowedRevolutions != null, () =>
        {
            RuleForEach(x => x.Overrides!.AllowedRevolutions!).InclusiveBetween(0.5m, 4m);
        });
    }
}
