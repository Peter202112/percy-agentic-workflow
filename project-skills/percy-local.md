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
Run this command in the background from `/Users/peterjoseph/Desktop/claude_poc/Percy/percy-web`:
```bash
source ~/.nvm/nvm.sh && nvm use && \
  PERCY_WEB_API_HOST=https://percy-enterprise.browserstack.com \
  PERCY_WEB_AUTH_TOKEN=e218fbb5f8aeee43688ea0afdf32613b6c6d94aa9cf7e858b47b588994bddaaa \
  yarn start
```

Run this in background with `run_in_background: true` and timeout of 600000ms.

### Step 4: Wait for build to complete (~90 seconds)
After ~90 seconds, check the output file tail for "Build successful" or errors.

### Step 5: Verify
- Check for "Build successful" and "Serving on https://localhost:4200/" in the output
- Check for any API connection errors (ECONNREFUSED, ENOTFOUND)
- Report the status to the user

### Key details
- **Node version:** v14.18.3 (from .nvmrc via nvm)
- **API Host:** percy-enterprise.browserstack.com (BrowserStack enterprise)
- **Auth token bypasses OAuth** — without it, login redirects away from localhost
- **Build time:** ~90-100 seconds
- **SSL:** serves on HTTPS (certs must be installed via `make certs` first time)
