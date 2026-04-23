using FluentAssertions;
using FreestyleCombo.API.Features.Combos.GenerateCombo;
using FreestyleCombo.API.Features.Combos.PreviewCombo;
using FreestyleCombo.API.Features.Preferences.CreatePreference;
using FreestyleCombo.API.Features.Preferences.UpdatePreferences;
using FreestyleCombo.API.Features.Tricks.CreateTrick;
using FreestyleCombo.API.Features.Tricks.UpdateTrick;
using FreestyleCombo.API.Features.TrickSubmissions.SubmitTrick;

namespace FreestyleCombo.Tests.Features;

public class RevolutionValidationTests
{
    [Fact]
    public void CreateTrickValidator_ShouldReject_RevolutionAboveFour()
    {
        var validator = new CreateTrickValidator();
        var result = validator.Validate(new CreateTrickCommand("ATW", "ATW", false, false, 4.5m, 6, 3, null, null, null));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Revolution");
    }

    [Fact]
    public void UpdateTrickValidator_ShouldAllow_RevolutionAtFour()
    {
        var validator = new UpdateTrickValidator();
        var result = validator.Validate(new UpdateTrickCommand(Guid.NewGuid(), "ATW", "ATW", false, false, 4m, 6, 3, null, null, null));

        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void SubmitTrickValidator_ShouldReject_RevolutionAboveFour()
    {
        var validator = new SubmitTrickValidator();
        var result = validator.Validate(new SubmitTrickCommand("ATW", "ATW", false, false, 4.5m, 6, 3));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Revolution");
    }

    [Fact]
    public void CreatePreferenceValidator_ShouldReject_AllowedRevolutionAboveFour()
    {
        var validator = new CreatePreferenceValidator();
        var result = validator.Validate(new CreatePreferenceCommand(
            Guid.NewGuid(),
            "Default",
            6,
            5,
            50,
            20,
            2,
            true,
            true,
            [1m, 4.5m]));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName.StartsWith("AllowedRevolutions"));
    }

    [Fact]
    public void UpdatePreferenceValidator_ShouldAllow_AllowedRevolutionAtFour()
    {
        var validator = new UpdatePreferencesValidator();
        var result = validator.Validate(new UpdatePreferencesCommand(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "Default",
            6,
            5,
            50,
            20,
            2,
            true,
            true,
            [1m, 4m]));

        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void GenerateComboValidator_ShouldReject_OverrideAllowedRevolutionAboveFour()
    {
        var validator = new GenerateComboValidator();
        var result = validator.Validate(new GenerateComboCommand(
            null,
            new GenerateComboOverrides
            {
                ComboLength = 4,
                AllowedRevolutions = [1m, 4.5m]
            }));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName.Contains("AllowedRevolutions"));
    }

    [Fact]
    public void PreviewComboValidator_ShouldReject_OverrideAllowedRevolutionAboveFour()
    {
        var validator = new PreviewComboValidator();
        var result = validator.Validate(new PreviewComboCommand(
            null,
            new GenerateComboOverrides
            {
                AllowedRevolutions = [4.5m]
            }));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName.Contains("AllowedRevolutions"));
    }
}
