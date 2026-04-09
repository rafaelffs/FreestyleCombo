FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY ["FreestyleCombo.API/FreestyleCombo.API.csproj", "FreestyleCombo.API/"]
COPY ["FreestyleCombo.Core/FreestyleCombo.Core.csproj", "FreestyleCombo.Core/"]
COPY ["FreestyleCombo.Infrastructure/FreestyleCombo.Infrastructure.csproj", "FreestyleCombo.Infrastructure/"]
COPY ["FreestyleCombo.AI/FreestyleCombo.AI.csproj", "FreestyleCombo.AI/"]
RUN dotnet restore "FreestyleCombo.API/FreestyleCombo.API.csproj"
COPY . .
WORKDIR "/src/FreestyleCombo.API"
RUN dotnet build "FreestyleCombo.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "FreestyleCombo.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "FreestyleCombo.API.dll"]
