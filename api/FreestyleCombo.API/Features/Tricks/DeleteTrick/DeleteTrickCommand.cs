using MediatR;

namespace FreestyleCombo.API.Features.Tricks.DeleteTrick;

public record DeleteTrickCommand(Guid Id) : IRequest;
