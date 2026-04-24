using FluentAssertions;
using FreestyleCombo.API.Features.Auth.Login;
using FreestyleCombo.API.Features.Auth.Register;
using FreestyleCombo.API.Features.Combos.BuildCombo;
using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.API.Features.Preferences.CreatePreference;
using FreestyleCombo.API.Features.Preferences.UpdatePreferences;
using FreestyleCombo.API.Features.Ratings.RateCombo;
using FreestyleCombo.API.Features.TrickSubmissions.SubmitTrick;
using FreestyleCombo.API.Features.Tricks.CreateTrick;

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

    [Fact]
    public void RateComboValidator_ShouldReject_ScoreAboveFive()
    {
        var validator = new RateComboValidator();
        var result = validator.Validate(new RateComboCommand(Guid.NewGuid(), Guid.NewGuid(), 6));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Score");
    }

    // ── GenerateComboValidator ─────────────────────────────────────────────

    [Fact]
    public void GenerateComboValidator_ShouldAccept_NullOverrides()
    {
        var validator = new GenerateComboValidator();
        var result = validator.Validate(new GenerateComboCommand(null, null));

        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void GenerateComboValidator_ShouldReject_ComboLengthAbove100()
    {
        var validator = new GenerateComboValidator();
        var result = validator.Validate(new GenerateComboCommand(null, new GenerateComboOverrides { ComboLength = 101 }));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName.Contains("ComboLength"));
    }

    [Fact]
    public void GenerateComboValidator_ShouldReject_MaxDifficultyAbove10()
    {
        var validator = new GenerateComboValidator();
        var result = validator.Validate(new GenerateComboCommand(null, new GenerateComboOverrides { MaxDifficulty = 11 }));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName.Contains("MaxDifficulty"));
    }

    [Fact]
    public void GenerateComboValidator_ShouldReject_MaxConsecutiveNoTouchAbove30()
    {
        var validator = new GenerateComboValidator();
        var result = validator.Validate(new GenerateComboCommand(null, new GenerateComboOverrides { MaxConsecutiveNoTouch = 31 }));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName.Contains("MaxConsecutiveNoTouch"));
    }

    [Fact]
    public void GenerateComboValidator_ShouldReject_NoTouchPercentageAbove100()
    {
        var validator = new GenerateComboValidator();
        var result = validator.Validate(new GenerateComboCommand(null, new GenerateComboOverrides { NoTouchPercentage = 101 }));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName.Contains("NoTouchPercentage"));
    }

    // ── CreatePreferenceValidator ──────────────────────────────────────────

    private static CreatePreferenceCommand ValidCreatePreference() => new(
        Guid.NewGuid(), "My Pref", 7, 10, 60, 30, 2, true, true, []);

    [Fact]
    public void CreatePreferenceValidator_ShouldAccept_ValidCommand()
    {
        var result = new CreatePreferenceValidator().Validate(ValidCreatePreference());
        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void CreatePreferenceValidator_ShouldReject_EmptyName()
    {
        var cmd = ValidCreatePreference() with { Name = "" };
        var result = new CreatePreferenceValidator().Validate(cmd);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Name");
    }

    [Fact]
    public void CreatePreferenceValidator_ShouldReject_NameTooLong()
    {
        var cmd = ValidCreatePreference() with { Name = new string('x', 101) };
        var result = new CreatePreferenceValidator().Validate(cmd);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Name");
    }

    [Fact]
    public void CreatePreferenceValidator_ShouldReject_ComboLengthAbove100()
    {
        var cmd = ValidCreatePreference() with { ComboLength = 101 };
        var result = new CreatePreferenceValidator().Validate(cmd);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "ComboLength");
    }

    [Fact]
    public void CreatePreferenceValidator_ShouldReject_MaxConsecutiveNoTouchAbove30()
    {
        var cmd = ValidCreatePreference() with { MaxConsecutiveNoTouch = 31 };
        var result = new CreatePreferenceValidator().Validate(cmd);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "MaxConsecutiveNoTouch");
    }

    // ── UpdatePreferencesValidator ─────────────────────────────────────────

    private static UpdatePreferencesCommand ValidUpdatePreference() => new(
        Guid.NewGuid(), Guid.NewGuid(), "My Pref", 7, 10, 60, 30, 2, true, true, []);

    [Fact]
    public void UpdatePreferencesValidator_ShouldAccept_ValidCommand()
    {
        var result = new UpdatePreferencesValidator().Validate(ValidUpdatePreference());
        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void UpdatePreferencesValidator_ShouldReject_EmptyName()
    {
        var cmd = ValidUpdatePreference() with { Name = "" };
        var result = new UpdatePreferencesValidator().Validate(cmd);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Name");
    }

    [Fact]
    public void UpdatePreferencesValidator_ShouldReject_NameTooLong()
    {
        var cmd = ValidUpdatePreference() with { Name = new string('x', 101) };
        var result = new UpdatePreferencesValidator().Validate(cmd);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Name");
    }

    [Fact]
    public void UpdatePreferencesValidator_ShouldReject_StrongFootPercentageAbove100()
    {
        var cmd = ValidUpdatePreference() with { StrongFootPercentage = 101 };
        var result = new UpdatePreferencesValidator().Validate(cmd);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "StrongFootPercentage");
    }

    // ── SubmitTrickValidator ───────────────────────────────────────────────

    private static SubmitTrickCommand ValidSubmitTrick() => new("Around The World", "ATW", false, false, 1.0m, 3, 5);

    [Fact]
    public void SubmitTrickValidator_ShouldAccept_ValidCommand()
    {
        var result = new SubmitTrickValidator().Validate(ValidSubmitTrick());
        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void SubmitTrickValidator_ShouldReject_EmptyName()
    {
        var cmd = ValidSubmitTrick() with { Name = "" };
        var result = new SubmitTrickValidator().Validate(cmd);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Name");
    }

    [Fact]
    public void SubmitTrickValidator_ShouldReject_AbbreviationTooLong()
    {
        var cmd = ValidSubmitTrick() with { Abbreviation = new string('A', 21) };
        var result = new SubmitTrickValidator().Validate(cmd);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Abbreviation");
    }

    [Fact]
    public void SubmitTrickValidator_ShouldReject_DifficultyAbove10()
    {
        var cmd = ValidSubmitTrick() with { Difficulty = 11 };
        var result = new SubmitTrickValidator().Validate(cmd);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Difficulty");
    }

    [Fact]
    public void SubmitTrickValidator_ShouldReject_CommonLevelAbove10()
    {
        var cmd = ValidSubmitTrick() with { CommonLevel = 11 };
        var result = new SubmitTrickValidator().Validate(cmd);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "CommonLevel");
    }

    // ── CreateTrickValidator ───────────────────────────────────────────────

    private static CreateTrickCommand ValidCreateTrick() =>
        new("Around The World", "ATW", false, false, 1.0m, 3, 4, null, null, null);

    [Fact]
    public void CreateTrickValidator_ShouldAccept_ValidCommand()
    {
        var result = new CreateTrickValidator().Validate(ValidCreateTrick());
        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void CreateTrickValidator_ShouldReject_EmptyName()
    {
        var cmd = ValidCreateTrick() with { Name = "" };
        var result = new CreateTrickValidator().Validate(cmd);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Name");
    }

    [Fact]
    public void CreateTrickValidator_ShouldReject_AbbreviationTooLong()
    {
        var cmd = ValidCreateTrick() with { Abbreviation = new string('A', 21) };
        var result = new CreateTrickValidator().Validate(cmd);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Abbreviation");
    }

    [Fact]
    public void CreateTrickValidator_ShouldReject_CommonLevelAbove5()
    {
        // CreateTrick uses max 5; SubmitTrick/UpdateTrick use max 10 — this validates the tighter bound
        var cmd = ValidCreateTrick() with { CommonLevel = 6 };
        var result = new CreateTrickValidator().Validate(cmd);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "CommonLevel");
    }

    [Fact]
    public void CreateTrickValidator_ShouldReject_DifficultyBelowOne()
    {
        var cmd = ValidCreateTrick() with { Difficulty = 0 };
        var result = new CreateTrickValidator().Validate(cmd);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Difficulty");
    }
}
