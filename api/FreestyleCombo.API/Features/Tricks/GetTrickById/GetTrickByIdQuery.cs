using MediatR;

namespace FreestyleCombo.API.Features.Tricks.GetTrickById;

public record GetTrickByIdQuery(Guid Id) : IRequest<TrickDetailDto>;
