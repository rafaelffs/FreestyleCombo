using FluentValidation;

namespace FreestyleCombo.API.Features.Auth.ExternalSignIn;

public class ExternalSignInValidator : AbstractValidator<ExternalSignInCommand>
{
    public ExternalSignInValidator()
    {
        RuleFor(x => x.Provider).NotEmpty();
        RuleFor(x => x.IdToken).NotEmpty();
    }
}
