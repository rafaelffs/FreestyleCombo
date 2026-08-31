using FreestyleCombo.API.Features.Combos.RemovePersonalReusable;
using FreestyleCombo.Core.Interfaces;
using Moq;

namespace FreestyleCombo.Tests.Features;

public class RemovePersonalReusableHandlerTests
{
    private readonly Guid _userId = Guid.NewGuid();
    private readonly Guid _comboId = Guid.NewGuid();

    [Fact]
    public async Task RemovePersonalReusable_CallsRepository()
    {
        var repo = new Mock<IUserPersonalReusableComboRepository>();
        repo.Setup(r => r.RemoveAsync(_userId, _comboId, It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);

        await new RemovePersonalReusableHandler(repo.Object)
            .Handle(new RemovePersonalReusableCommand(_comboId, _userId), CancellationToken.None);

        repo.Verify(r => r.RemoveAsync(_userId, _comboId, It.IsAny<CancellationToken>()), Times.Once);
    }
}
