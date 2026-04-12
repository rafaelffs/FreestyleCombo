# FreestyleCombo

A full-stack freestyle football combo generator. Users register/login, generate combos with AI-written descriptions (powered by Claude), rate each other's public combos, and save their preferences. A Hangfire background job runs weekly to adjust trick difficulty weights based on aggregate ratings.

---

## Table of Contents

- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Running with Docker (recommended)](#running-with-docker-recommended)
- [Running Locally (without Docker)](#running-locally-without-docker)
- [Environment Variables](#environment-variables)
- [Database Migrations](#database-migrations)
- [Tests](#tests)
- [Mobile Setup](#mobile-setup)
- [Project Structure](#project-structure)

---

## Architecture

```
FreestyleCombo/
├── api/                          # ASP.NET Core 10, Vertical Slice, .NET 9
│   ├── FreestyleCombo.Core/      # Entities, Interfaces, Result<T>
│   ├── FreestyleCombo.Infrastructure/  # EF Core, Repositories, Seeder, Migrations
│   ├── FreestyleCombo.AI/        # Anthropic SDK (ComboEnhancerService), Hangfire job
│   ├── FreestyleCombo.API/       # MediatR Vertical Slices, Controllers, Program.cs
│   └── FreestyleCombo.Tests/     # xUnit + FluentAssertions + Moq
├── web/                          # React 19, Vite, TypeScript, Tailwind v4, TanStack Query
├── mobile/                       # Flutter (Dart), go_router, dio, shared_preferences
├── docker-compose.yml            # postgres:16, api (host port 5050)
└── .github/workflows/ci.yml      # Runs on push to main/feature/**
```

---

## Tech Stack

### API
- **ASP.NET Core 10** with Vertical Slice architecture
- **MediatR** for request/handler dispatching
- **FluentValidation** as a MediatR pipeline behavior
- **EF Core + Npgsql** for database access
- **ASP.NET Core Identity** (`IdentityUser<Guid>`) for user management
- **JWT Bearer** authentication
- **Hangfire + Hangfire.PostgreSql** for background jobs
- **Anthropic.SDK 5.10.0** for AI combo descriptions
- **Swashbuckle 10 / Microsoft.OpenApi 2.0** for Swagger UI

### Web
- **React 19 + Vite + TypeScript**
- **Tailwind CSS v4** (`@tailwindcss/vite`)
- **TanStack Query v5**
- **React Router v7**
- **axios**
- **shadcn-style components** (Radix UI + CVA + clsx + tailwind-merge)

### Mobile
- **Flutter 3.19+ / Dart 3.3+**
- **go_router** for navigation
- **dio** for HTTP requests
- **shared_preferences** for token storage
- Plain `StatefulWidget` + `FutureBuilder` — no external state management

---

## Prerequisites

| Tool | Minimum version | Notes |
|---|---|---|
| Docker + Docker Compose | any recent | Required for the Docker path |
| .NET SDK | 9.0 | Required for the local API path |
| Node.js | 18+ | Required for the local web path |
| Flutter SDK | 3.19+ | Required for mobile |
| PostgreSQL | 16 | Only if running API locally without Docker |

---

## Running with Docker (recommended)

This starts PostgreSQL and the API together.

```bash
# From the project root
docker-compose up
```

| Service | URL |
|---|---|
| API | http://localhost:5050 |
| Swagger UI | http://localhost:5050/swagger |
| Hangfire dashboard | http://localhost:5050/hangfire |

The web frontend is **not** included in Docker — run it separately (see below).

> **Anthropic API key:** `appsettings.Development.json` is gitignored. Set `Anthropic__ApiKey` as an environment variable or add it to `docker-compose.yml` under the `api` service's `environment` block.

---

## Running Locally (without Docker)

You need a local PostgreSQL instance on port 5432 before starting.

### API

```bash
cd api/FreestyleCombo.API
dotnet run
# API available at http://localhost:5050
```

### Web

```bash
cd web
npm install
npm run dev
# Frontend available at http://localhost:5173
# Dev server proxies /api/* → http://localhost:5050
```

### Mobile

See the [Mobile Setup](#mobile-setup) section below.

---

## Environment Variables

| Variable | Where | Description |
|---|---|---|
| `ConnectionStrings__DefaultConnection` | docker-compose / appsettings | PostgreSQL connection string |
| `JwtSettings__Secret` | docker-compose / appsettings | JWT signing secret — minimum 32 characters |
| `JwtSettings__Issuer` | docker-compose / appsettings | `FreestyleComboAPI` |
| `JwtSettings__Audience` | docker-compose / appsettings | `FreestyleComboApp` |
| `Anthropic__ApiKey` | docker-compose / appsettings | Your Anthropic API key |

Example `appsettings.Development.json` (not committed):

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Database=freestylecombo;Username=postgres;Password=yourpassword"
  },
  "JwtSettings": {
    "Secret": "your-super-secret-key-minimum-32-chars",
    "Issuer": "FreestyleComboAPI",
    "Audience": "FreestyleComboApp"
  },
  "Anthropic": {
    "ApiKey": "sk-ant-..."
  }
}
```

---

## Database Migrations

Run from the `api/` directory:

```bash
cd api

# Add a new migration
dotnet ef migrations add <MigrationName> \
  --project FreestyleCombo.Infrastructure \
  --startup-project FreestyleCombo.API

# Apply migrations
dotnet ef database update \
  --project FreestyleCombo.Infrastructure \
  --startup-project FreestyleCombo.API
```

---

## Tests

```bash
cd api
dotnet test
```

11 unit tests covering:
- Combo generation: length, no-match, NoTouch logic, display text, preferences
- Rating validation: own combo, duplicate rating, not found, private combo
- Weight adjustment background job

---

## Mobile Setup

Flutter must be installed before running these steps.

```bash
cd mobile

# First time only — scaffold platform folders if they don't exist
flutter create . --org com.rafaelffs --project-name freestyle_combo --platforms android,ios

flutter pub get
flutter run
```

### API base URL

Edit [mobile/lib/core/api/api_client.dart](mobile/lib/core/api/api_client.dart) and set `kBaseUrl` based on your target:

| Target | URL |
|---|---|
| Android emulator | `http://10.0.2.2:5050/api` (default) |
| iOS simulator | `http://localhost:5050/api` |
| Physical device | `http://<your-local-ip>:5050/api` |

---

## Project Structure

### API — Data Model

| Entity | Key fields |
|---|---|
| `AppUser` | `IdentityUser<Guid>`, `ICollection<Combo>`, `ICollection<ComboRating>`, `UserPreference?` |
| `Trick` | `Id, Name, Abbreviation, CrossOver, Knee, Motion, Difficulty, CommonLevel` |
| `Combo` | `Id, OwnerId, TotalDifficulty, TrickCount, IsPublic, CreatedAt, AiDescription` |
| `ComboTrick` | `Id, ComboId, TrickId, Position, StrongFoot, NoTouch` |
| `ComboRating` | `Id, ComboId, RatedByUserId, Score, CreatedAt` |
| `UserPreference` | `Id, UserId, MaxDifficulty, ComboLength, StrongFootPercentage, NoTouchPercentage, MaxConsecutiveNoTouch, IncludeCrossOver, IncludeKnee, AllowedMotions` (`jsonb`) |

### Combo Generation Algorithm

1. Filter trick pool by `MaxDifficulty`, `IncludeCrossOver`, `IncludeKnee`, `AllowedMotions`
2. Split slots: `StrongFootPercentage` → strong-foot slots, remainder → weak-foot slots
3. Weighted random pick (weight = `CommonLevel`); fill by position
4. Shuffle positions
5. Annotate NoTouch — only on CrossOver tricks, respecting `NoTouchPercentage` and `MaxConsecutiveNoTouch`
6. Call Claude via `IComboEnhancerService.EnhanceAsync()` → AI description → save combo

### Web — Directory Structure

```
web/src/
├── lib/
│   ├── api.ts          # axios instance, all API functions + DTO types
│   ├── auth.ts         # localStorage token management
│   └── utils.ts        # cn() helper (clsx + tailwind-merge)
├── components/
│   ├── ui/             # Button, Input, Label, Card, Badge, Textarea, Select, Dialog
│   └── layout/         # Navbar, Layout (Outlet), ProtectedRoute
└── features/
    ├── auth/           # LoginPage, RegisterPage
    ├── combos/         # GenerateComboPage, PublicCombosPage, MyCombosPage,
    │                   # ComboDetailPage, ComboCard, RateComboDialog
    └── preferences/    # PreferencesPage
```

### Mobile — Directory Structure

```
mobile/lib/
├── main.dart
├── core/
│   ├── api/api_client.dart       # Dio client, all API methods, singleton
│   ├── auth/auth_service.dart    # Token in SharedPreferences, singleton
│   └── models/
│       ├── combo.dart            # ComboDto, ComboTrickDto, PagedResult, GenerateComboOverrides
│       └── user_preference.dart  # UserPreference with toJson/copyWith
├── features/
│   ├── auth/                     # login_screen.dart, register_screen.dart
│   ├── combos/                   # generate_combo_screen, public_combos_screen,
│   │                             # my_combos_screen, combo_detail_screen
│   └── preferences/              # preferences_screen.dart
├── router/app_router.dart        # GoRouter config, auth redirect
└── widgets/
    ├── main_shell.dart           # BottomNavigationBar shell (ShellRoute)
    ├── combo_card.dart           # Reusable card: display, tricks, AI description, actions
    └── rate_combo_dialog.dart    # Star rating AlertDialog
```

---

## CI

GitHub Actions at `.github/workflows/ci.yml` — triggers on push to `main` and `feature/**`.

Repo: https://github.com/rafaelffs/FreestyleCombo
