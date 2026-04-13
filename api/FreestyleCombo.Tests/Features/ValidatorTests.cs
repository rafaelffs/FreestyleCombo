using FluentAssertions;
using FreestyleCombo.API.Features.Auth.Login;
using FreestyleCombo.API.Features.Auth.Register;
using FreestyleCombo.API.Features.Combos.BuildCombo;
using FreestyleCombo.API.Features.Ratings.RateCombo;

namespace FreestyleCombo.Tests.Features;

public class ValidatorTests
{
    [Fact]
    public void BuildComboValidator_ShouldReject_EmptyTricksList()
    {
        var validator = new BuildComboValidator();
        var result = validator.Validate(new BuildComboCommand([]));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Tricks");
    }

    [Fact]
    public void BuildComboValidator_ShouldReject_PositionLessThanOne()
    {
        var validator = new BuildComboValidator();
        var result = validator.Validate(new BuildComboCommand(
            [new BuildComboTrickItem(Guid.NewGuid(), 0, true, false)]));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName.Contains("Position"));
    }

    [Fact]
    public void BuildComboValidator_ShouldAccept_ValidTricks()
    {
        var validator = new BuildComboValidator();
        var result = validator.Validate(new BuildComboCommand(
            [new BuildComboTrickItem(Guid.NewGuid(), 1, true, false)]));

        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void LoginValidator_ShouldReject_EmptyCredential()
    {
        var validator = new LoginValidator();
        var result = validator.Validate(new LoginCommand("", "password"));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Credential");
    }

    [Fact]
    public void LoginValidator_ShouldReject_CredentialTooLong()
    {
        var validator = new LoginValidator();
        var result = validator.Validate(new LoginCommand(new string('a', 257), "password"));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Credential");
    }

    [Fact]
    public void LoginValidator_ShouldReject_EmptyPassword()
    {
        var validator = new LoginValidator();
        var result = validator.Validate(new LoginCommand("user@example.com", ""));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Password");
    }

    [Fact]
    public void RegisterValidator_ShouldReject_InvalidEmail()
    {
        var validator = new RegisterValidator();
        var result = validator.Validate(new RegisterCommand("not-an-email", "validuser", "Password1!"));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Email");
    }

    [Fact]
    public void RegisterValidator_ShouldReject_PasswordTooShort()
    {
        var validator = new RegisterValidator();
        var result = validator.Validate(new RegisterCommand("user@example.com", "validuser", "123"));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Password");
    }

    [Fact]
    public void RegisterValidator_ShouldReject_UsernameTooShort()
    {
        var validator = new RegisterValidator();
        var result = validator.Validate(new RegisterCommand("user@example.com", "ab", "Password1!"));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "UserName");
    }

    [Fact]
    public void RateComboValidator_ShouldReject_ScoreBelowOne()
    {
        var validator = new RateComboValidator();
        var result = validator.Validate(new RateComboCommand(Guid.NewGuid(), Guid.NewGuid(), 0));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Score");
    }

    [Fact]
    public void RateComboValidator_ShouldAccept_ScoreFive()
    {
        var validator = new RateComboValidator();
        var result = validator.Validate(new RateComboCommand(Guid.NewGuid(), Guid.NewGuid(), 5));

        result.IsValid.Should().BeTrue();
    }
}
