using FluentValidation;

namespace FreestyleCombo.API.Features.Combos.BuildCombo;

public class BuildComboValidator : AbstractValidator<BuildComboCommand>
{
    public BuildComboValidator()
    {
        RuleFor(x => x.Tricks).NotEmpty().WithMessage("A combo must have at least one trick.");
        RuleForEach(x => x.Tricks).ChildRules(trick =>
        {
            trick.RuleFor(t => t.TrickId).NotEmpty();
            trick.RuleFor(t => t.Position).GreaterThanOrEqualTo(1);
        });
    }
}
