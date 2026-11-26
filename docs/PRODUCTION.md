# MEWMER — PRODUCTION BACKEND DEPLOYMENT GUIDE

This guide covers deploying the Mewmer Go backend to a production VPS. The frontend Flutter app and Astro web app are deployed separately; this document focuses on the Go API.

---

## 1. What You Need

- A VPS with a public IP (Ubuntu 24.04 LTS recommended).
- Root or sudo SSH access.
- A domain name pointing at the VPS (e.g. `api.mewmer.com`).
- A Cloudflare R2 account with two buckets created.
- A PostgreSQL 17 database (can run on the same VPS or a managed host).

---

## 2. Provision the Server

### 2.1 Create a non-root user

```bash
ssh root@<vps-ip>
adduser mewmer
usermod -aG sudo mewmer
su - mewmer
```

### 2.2 Install system dependencies

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential curl git ca-certificates nginx certbot python3-certbot-nginx postgresql postgresql-contrib
```

The backend does **not** need FFmpeg. All sticker generation happens on the client.

### 2.3 Install Go

```bash
curl -LO https://go.dev/dl/go1.24.0.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.24.0.linux-amd64.tar.gz
rm go1.24.0.linux-amd64.tar.gz
```

Add to `~/.bashrc`:

```bash
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
```

Then reload:

```bash
source ~/.bashrc
go version
```

---

## 3. Set Up PostgreSQL

### 3.1 Create the database and user

```bash
sudo -u postgres psql
```

```sql
CREATE USER mewmer WITH PASSWORD 'a-strong-db-password';
CREATE DATABASE mewmer OWNER mewmer;
GRANT ALL PRIVILEGES ON DATABASE mewmer TO mewmer;
\c mewmer
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
\q
```

Save the connection string for the environment file:

```text
DATABASE_URL=postgres://mewmer:a-strong-db-password@localhost:5432/mewmer?sslmode=disable
```

For production, prefer `sslmode=require` if PostgreSQL is configured with TLS.

---

## 4. Configure Cloudflare R2

### 4.1 Create buckets

- `mewmer-public-media` — for meme templates and future public memes.
- `mewmer-private-media` — for sticker packs, tray icons, and stickers.

### 4.2 Create an R2 API token

In the Cloudflare dashboard:

1. Go to **Manage R2 API Tokens**.
2. Create a token with **Object Read & Write** permissions for both buckets.
3. Note the **Access Key ID** and **Secret Access Key**.

### 4.3 Optional: custom domain for public bucket

1. In the R2 bucket settings, add a custom domain (e.g. `media.mewmer.com`).
2. Wait for Cloudflare to show **Active**.
3. Set `R2_PUBLIC_ENDPOINT=https://media.mewmer.com`.

If you do not use a custom domain, leave `R2_PUBLIC_ENDPOINT` empty and public files will be served through the default R2 endpoint.

### 4.4 Find your account ID

Copy the **Account ID** from the R2 overview page and set it as `R2_ACCOUNT_ID`.

---

## 5. Build and Configure the Backend

### 5.1 Clone and build

```bash
cd /var/www
git clone https://github.com/dushmanta05/mewmer.git mewmer
cd mewmer/server
go mod download
CGO_ENABLED=0 go build -o mewmer-api .
```

### 5.2 Create environment file

Create `/var/www/mewmer/server/.env`:

```bash
sudo mkdir -p /var/www/mewmer/server
sudo nano /var/www/mewmer/server/.env
```

Example:

```env
DATABASE_URL=postgres://mewmer:a-strong-db-password@localhost:5432/mewmer?sslmode=disable
PORT=3030
STORAGE_TYPE=r2
STORAGE_DIR=./uploads
CORS_ORIGIN=https://mewmer.com
SESSION_TTL=168h
SECURE_COOKIE=true
COOKIE_DOMAIN=mewmer.com

R2_ACCOUNT_ID=your-cloudflare-account-id
R2_ACCESS_KEY_ID=your-r2-access-key-id
R2_SECRET_ACCESS_KEY=your-r2-secret-access-key
R2_PUBLIC_BUCKET=mewmer-public-media
R2_PRIVATE_BUCKET=mewmer-private-media
R2_PUBLIC_ENDPOINT=https://media.mewmer.com
```

Notes:

- `STORAGE_TYPE=r2` is required for production. The default `filesystem` mode is for local development only.
- `SECURE_COOKIE=true` is required when serving over HTTPS.
- `CORS_ORIGIN` should match the web frontend origin.

### 5.3 Set permissions

```bash
sudo chown -R mewmer:mewmer /var/www/mewmer
sudo chmod 600 /var/www/mewmer/server/.env
```

---

## 6. Run Migrations

```bash
cd /var/www/mewmer/server
export $(grep -v '^#' .env | xargs)
psql "$DATABASE_URL" -f migrations/001_initial_schema.sql
psql "$DATABASE_URL" -f migrations/002_identity_and_sessions.sql
psql "$DATABASE_URL" -f migrations/003_meme_templates.sql
psql "$DATABASE_URL" -f migrations/004_sticker_cloud.sql
psql "$DATABASE_URL" -f migrations/005_pack_tags.sql
```

Use a migration tool (e.g. `golang-migrate`) once the project grows; for now the raw SQL files are applied in order.

---

## 7. Create the First Admin

Run the CLI tool once with the credentials you want. Do **not** save `ADMIN_PASSWORD` in `.env`.

```bash
cd /var/www/mewmer/server
export ADMIN_EMAIL=you@mewmer.com
export ADMIN_USERNAME=you
export ADMIN_DISPLAY_NAME="Your Name"
export ADMIN_PASSWORD="a very strong password"
./mewmer-api create-admin
```

If the email already exists, the tool updates the password and forces the role to `admin`.

---

## 8. Run the Backend as a systemd Service

### 8.1 Create service file

```bash
sudo nano /etc/systemd/system/mewmer-api.service
```

```ini
[Unit]
Description=Mewmer Go Backend
After=network.target postgresql.service

[Service]
Type=simple
User=mewmer
Group=mewmer
WorkingDirectory=/var/www/mewmer/server
ExecStart=/var/www/mewmer/server/mewmer-api
Restart=on-failure
RestartSec=5
EnvironmentFile=/var/www/mewmer/server/.env

[Install]
WantedBy=multi-user.target
```

### 8.2 Start and enable

```bash
sudo systemctl daemon-reload
sudo systemctl enable mewmer-api
sudo systemctl start mewmer-api
sudo systemctl status mewmer-api
```

### 8.3 Check health

```bash
curl http://127.0.0.1:3030/health
```

Expected response:

```json
{"service":"mewmer-api","status":"ok"}
```

---

## 9. Reverse Proxy with Nginx and HTTPS

### 9.1 Create Nginx config

```bash
sudo nano /etc/nginx/sites-available/mewmer-api
```

```nginx
server {
    listen 80;
    server_name api.mewmer.com;

    location / {
        proxy_pass http://127.0.0.1:3030;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable it:

```bash
sudo ln -s /etc/nginx/sites-available/mewmer-api /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 9.2 Obtain TLS certificate

```bash
sudo certbot --nginx -d api.mewmer.com
```

Follow the prompts. Certbot will update the Nginx config automatically.

### 9.3 Verify HTTPS health

```bash
curl https://api.mewmer.com/health
```

---

## 10. Firewall

Allow only SSH, HTTP, and HTTPS:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

Port `3030` should **not** be exposed publicly; Nginx proxies to it on localhost.

---

## 11. Updates and Redeploys

When the code changes:

```bash
cd /var/www/mewmer
sudo -u mewmer git pull origin main
cd server
sudo -u mewmer go mod download
sudo -u mewmer CGO_ENABLED=0 go build -o mewmer-api .
sudo systemctl restart mewmer-api
```

Always run migrations before restarting if a new migration file was added:

```bash
cd /var/www/mewmer/server
export $(grep -v '^#' .env | xargs)
psql "$DATABASE_URL" -f migrations/NNN_new_migration.sql
sudo systemctl restart mewmer-api
```

---

## 12. Mobile App Connectivity

The Flutter app must point at the production domain, not `localhost`:

```env
API_BASE_URL=https://api.mewmer.com/api/v1
```

Make sure the domain's TLS certificate is valid and the phone can reach `api.mewmer.com` over the internet.

---

## 13. Monitoring Checklist

- `sudo systemctl status mewmer-api` — service health.
- `sudo journalctl -u mewmer-api -f` — live logs.
- `curl https://api.mewmer.com/health` — API health.
- PostgreSQL backups — configure `pg_dump` or a managed backup.
- R2 bucket lifecycle rules — enable object versioning if desired.

---

## 14. Notes for This Deployment

- No private sticker packs exist yet, so there is no private media to migrate. The private bucket only needs to exist and have the API token permissions configured.
- The backend does **not** run FFmpeg. Do not install FFmpeg on the VPS unless you add a separate, unrelated media-processing service later.
