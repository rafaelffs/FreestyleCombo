# Deployment Plan: FreestyleCombo MVP to Production

## Context
The app is ready for public deployment. The goal is the cheapest viable production setup: a single Hetzner VPS running Docker Compose (API + PostgreSQL) + host Nginx, with the React web app served as static files from Nginx. Mobile apps will be prepared for release (production API URL, signing config) but NOT submitted to app stores yet. CI already exists; we need to add CD.

---

## Architecture

```
Internet
  └── Host Nginx (80/443, Let's Encrypt SSL)
           ↓ (localhost)
        Docker containers (internal, no port exposure to internet):
        ├── api:8080    (ASP.NET Core + Hangfire)
        ├── db:5432     (PostgreSQL)
        
Host filesystem:
  /var/www/freestylecombo  (React static files, updated via CD)
```

---

## Phase 1: VPS Setup (manual, one-time)

1. **Provision Hetzner CX22** (~€4.49/mo): 2 vCPU, 4GB RAM, Ubuntu 24.04
2. **Install on server**:
   ```bash
   apt update && apt install -y docker.io docker-compose-v2 nginx
   systemctl enable docker
   ```
3. **Create `/opt/freestylecombo/.env`** on server (gitignored):
   ```
   POSTGRES_PASSWORD=<strong-random>
   JWT_SECRET=<min-32-char-random>
   ANTHROPIC_API_KEY=<your-key>   # keep for future use, not active
   ```
4. **Initial access**: use the raw VPS IP (`http://<IP>`) — HTTP only, fine for private testing

### When you get a domain (future step)
1. Buy a domain (e.g. `freestylecombo.app`) from Namecheap or Porkbun (~$10-15/yr)
2. Add an A record pointing to your VPS IP
3. Install Certbot: `apt install -y certbot python3-certbot-nginx`
4. Issue SSL cert: `certbot --nginx -d freestylecombo.app`
5. Update `nginx/nginx.conf` `server_name` from `_` to `freestylecombo.app`
6. Update mobile `_baseUrl` from `http://<IP>/api` → `https://freestylecombo.app/api`

---

## Phase 2: New Files to Create

### `docker-compose.prod.yml`
**Strategy**: Nginx runs as a host systemd service (installed via `apt`). API container exposes port `5050` only to `localhost` (not visible to the internet). Host Nginx reverse-proxies to `localhost:5050`.

Changes from dev compose:
  - Removes port exposure on `db` (Docker-internal only)
  - API port `5050:8080` set to `127.0.0.1:5050:8080` (localhost only)
  - Database `db` has no exposed ports
  - Env vars read from `/opt/freestylecombo/.env` file
  - All services have `restart: unless-stopped`
  - Uses `docker_default` bridge network (Docker Compose auto-creates it)

### `nginx/nginx.conf`
Deployed to `/etc/nginx/conf.d/freestylecombo.conf` on the VPS (replaces the snipppet in the plan below). This Nginx runs as a **host systemd service**, not in Docker.

Initial version (HTTP only, no domain yet):
```nginx
server {
    listen 80;
    server_name _;

    root /var/www/freestylecombo;
    index index.html;

    # Proxy API requests to the Docker container's localhost-only port
    location /api/ {
        proxy_pass http://127.0.0.1:5050/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Serve React app; SPA fallback to index.html for client-side routing
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

Once Certbot + domain are set up, re-run: `certbot --nginx -d freestylecombo.app` — it will automatically update this file to add HTTPS and redirect HTTP to HTTPS.

---

## Phase 3: GitHub Actions CD (`.github/workflows/deploy.yml`)

Triggered on push to `main` after CI passes.

Steps:
1. Build React app: `npm ci && npm run build` → produces `web/dist/`
2. Sync config files to server:
   ```bash
   rsync -avz docker-compose.prod.yml ubuntu@$DEPLOY_HOST:/opt/freestylecombo/
   rsync -avz nginx/nginx.conf ubuntu@$DEPLOY_HOST:/opt/freestylecombo/nginx.conf.new
   ```
3. Sync React build to server:
   ```bash
   rsync -avz --delete web/dist/ ubuntu@$DEPLOY_HOST:/var/www/freestylecombo/
   ```
4. SSH into server and deploy:
   ```bash
   ssh ubuntu@$DEPLOY_HOST 'cd /opt/freestylecombo && docker compose -f docker-compose.prod.yml up --build -d'
   ```
5. (Optionally) Update Nginx config if it changed:
   ```bash
   ssh ubuntu@$DEPLOY_HOST 'sudo mv /opt/freestylecombo/nginx.conf.new /etc/nginx/conf.d/freestylecombo.conf && sudo nginx -t && sudo systemctl reload nginx'
   ```

GitHub Secrets needed:
- `DEPLOY_HOST` — VPS IP (e.g. `1.2.3.4`)
- `DEPLOY_USER` — `ubuntu`
- `DEPLOY_SSH_KEY` — private key (public key added to VPS `~/.ssh/authorized_keys`)

**First-time setup on server** (manual, one-time before CD works):
```bash
# Create app directory and web root
sudo mkdir -p /opt/freestylecombo /var/www/freestylecombo
sudo chown ubuntu:ubuntu /opt/freestylecombo /var/www/freestylecombo

# Create initial Nginx config
sudo cp /opt/freestylecombo/nginx.conf /etc/nginx/conf.d/freestylecombo.conf
sudo nginx -t
sudo systemctl reload nginx

# Run initial database migrations (one-time)
cd /opt/freestylecombo
docker compose -f docker-compose.prod.yml up --build -d
docker compose -f docker-compose.prod.yml exec api dotnet ef database update --project FreestyleCombo.Infrastructure --startup-project FreestyleCombo.API

# Verify
curl http://localhost:5050/swagger  # Should see Swagger UI
curl http://localhost/  # Should see React app
```

---

## Phase 4: Mobile — Prepare for Future Release (no store submission yet)

**Goal**: get the mobile app pointing at production and fully buildable in release mode. Store submission is deferred.

### 4a. Production API URL
**File**: `mobile/lib/core/api/api_client.dart`

Switch URL based on build mode. Use the raw VPS IP for now; swap to domain once available:
```dart
import 'package:flutter/foundation.dart';

static final String _baseUrl = kReleaseMode
    ? 'http://<VPS-IP>/api'          // → 'https://freestylecombo.app/api' once domain is live
    : 'http://10.0.2.2:5050/api';    // Android emulator dev default
```

> **Note**: Until HTTPS is set up, Android release builds need `android:usesCleartextTraffic="true"` in `AndroidManifest.xml`. Remove this once the domain + SSL is in place.

### 4b. Android — Signing setup (no Play Store upload yet)
1. Generate a keystore (keep it out of git):
   ```bash
   keytool -genkey -v -keystore android/upload-keystore.jks \
     -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```
2. Create `android/key.properties` (gitignored):
   ```
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```
3. Wire up `android/app/build.gradle` to read `key.properties` for release builds
4. Verify: `flutter build appbundle --release` produces a signed `.aab`

### 4c. iOS — Signing setup (no App Store upload yet)
1. Set bundle identifier in `ios/Runner.xcodeproj` (e.g. `com.rafaelffs.freestylecombo`)
2. Enroll in Apple Developer Program ($99/yr) when ready to publish
3. For now, verify: `flutter build ios --release --no-codesign` compiles without errors

### 4d. When ready to publish (future step)
- **Android**: Upload `.aab` to Google Play Console → Internal Testing → Production
- **iOS**: Configure automatic signing in Xcode, `flutter build ipa --release`, upload via Xcode Organizer or Transporter

---

## Critical Files

| File | Action |
|---|---|
| `docker-compose.prod.yml` | Create |
| `nginx/nginx.conf` | Create (reference config, deployed manually to server) |
| `.github/workflows/deploy.yml` | Create |
| `mobile/lib/core/api/api_client.dart` | Update base URL |
| `docker-compose.yml` | No change (stays as local dev) |

---

## Verification

**After first CD deployment:**
1. Visit `http://<VPS-IP>` — React app should load
2. Visit `http://<VPS-IP>/swagger` — Swagger UI should load (API is working)
3. Register a new account
4. Login — check that JWT is issued
5. Generate a combo — check Hangfire job runs (visit `http://<VPS-IP>/hangfire` to see dashboard)
6. Rate a combo, favourite a combo — core flows work
7. Inspect logs: `docker compose -f docker-compose.prod.yml logs -f api`

**On subsequent CD pushes:**
- React app updates via rsync
- API container rebuilds if any source changed
- Database migrations run automatically (via EF Core seeder or explicit step)

**After domain + SSL added:**
- Re-run `certbot --nginx -d freestylecombo.app` on the server
- Update mobile `_baseUrl` from `http://<IP>/api` → `https://freestylecombo.app/api`
- Verify all flows over HTTPS and confirm HTTP→HTTPS redirect works
- Update CLAUDE.md to reflect the live domain URL
