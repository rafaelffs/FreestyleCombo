using FluentValidation;

namespace FreestyleCombo.API.Features.Ratings.RateCombo;

public class RateComboValidator : AbstractValidator<RateComboCommand>
{
    public RateComboValidator()
    {
        RuleFor(x => x.Score).InclusiveBetween(1, 5);
    }
}
