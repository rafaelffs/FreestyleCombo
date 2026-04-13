.PHONY: dev api web mobile test docker-up docker-down docker-build docker-logs clean

# ---------------------------------------------------------------
# dev — start API + web in parallel, Flutter in a new Terminal window
# ---------------------------------------------------------------
dev:
	@echo "Starting API, Web, and Mobile..."
	@osascript -e 'tell application "Terminal" to do script "cd $(CURDIR)/mobile && flutter run -d chrome"'
	@trap 'kill 0' SIGINT; \
	  (cd api/FreestyleCombo.API && dotnet watch run) & \
	  (cd web && npm run dev) & \
	  (sleep 6 && open http://localhost:5050/swagger && open http://localhost:5173) & \
	  wait

# ---------------------------------------------------------------
# individual layers
# ---------------------------------------------------------------
api:
	cd api/FreestyleCombo.API && dotnet watch run

web:
	cd web && npm run dev

mobile:
	cd mobile && flutter run -d chrome

# ---------------------------------------------------------------
# tests
# ---------------------------------------------------------------
test:
	cd api && dotnet test

# ---------------------------------------------------------------
# docker (local docker-compose)
# ---------------------------------------------------------------
docker-up:
	docker-compose up -d

docker-down:
	docker-compose down

docker-build:
	docker-compose up -d --build

docker-logs:
	docker-compose logs -f api

# ---------------------------------------------------------------
# install dependencies
# ---------------------------------------------------------------
install:
	cd web && npm install
	cd mobile && flutter pub get
	cd api && dotnet restore

# ---------------------------------------------------------------
# EF Core migrations
# ---------------------------------------------------------------
migration:
	@read -p "Migration name: " name; \
	cd api && dotnet ef migrations add $$name \
	  --project FreestyleCombo.Infrastructure \
	  --startup-project FreestyleCombo.API

migrate:
	cd api && dotnet ef database update \
	  --project FreestyleCombo.Infrastructure \
	  --startup-project FreestyleCombo.API

# ---------------------------------------------------------------
# clean build artifacts
# ---------------------------------------------------------------
clean:
	cd api && dotnet clean
	cd web && rm -rf dist node_modules/.cache
	cd mobile && flutter clean
