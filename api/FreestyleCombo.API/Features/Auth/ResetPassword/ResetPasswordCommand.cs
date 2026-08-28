using FluentValidation;
using MediatR;

namespace FreestyleCombo.API.Features.Auth.ResetPassword;

public record ResetPasswordCommand(string Email, string Code, string NewPassword) : IRequest;

public class ResetPasswordValidator : AbstractValidator<ResetPasswordCommand>
{
    public ResetPasswordValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.Code).NotEmpty().Length(6);
        RuleFor(x => x.NewPassword).NotEmpty().MinimumLength(6);
    }
}
