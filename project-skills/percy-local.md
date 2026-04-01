---
name: percy-local
description: Start, restart, or check percy-web dev server at localhost:4200 connected to production backend
user-invocable: true
---

# Percy Local Dev Server

Start, restart, or check the percy-web development server at https://localhost:4200 connected to the BrowserStack production backend.

## Instructions

When the user invokes this skill, perform the following steps:

### Step 1: Kill any existing server on port 4200
```bash
lsof -ti:4200 | xargs kill 2>/dev/null; sleep 1
```

### Step 2: Verify the port is free
```bash
lsof -ti:4200 2>/dev/null && echo "STILL IN USE" || echo "Port 4200 is free"
```

### Step 3: Start the server
Run this command in the background from your `percy-web/` directory:
```bash
source ~/.nvm/nvm.sh && nvm use && \
  PERCY_WEB_API_HOST=<YOUR_PERCY_API_HOST> \
  PERCY_WEB_AUTH_TOKEN=<YOUR_PERCY_AUTH_TOKEN> \
  yarn start
```

> **Setup:** Set these env vars for your Percy instance. For BrowserStack Percy, the API host
> is typically `https://percy.io` or your enterprise URL. Get your auth token from
> Percy Profile Settings → User Token.

Run this in background with `run_in_background: true` and timeout of 600000ms.

### Step 4: Wait for build to complete (~90 seconds)
After ~90 seconds, check the output file tail for "Build successful" or errors.

### Step 5: Verify
- Check for "Build successful" and "Serving on https://localhost:4200/" in the output
- Check for any API connection errors (ECONNREFUSED, ENOTFOUND)
- Report the status to the user

### Key details
- **Node version:** v14.18.3 (from .nvmrc via nvm)
- **API Host:** Set via `PERCY_WEB_API_HOST` env var (your Percy instance URL)
- **Auth token bypasses OAuth** — set via `PERCY_WEB_AUTH_TOKEN` (from Percy Profile Settings)
- **Build time:** ~90-100 seconds
- **SSL:** serves on HTTPS (certs must be installed via `make certs` first time)
