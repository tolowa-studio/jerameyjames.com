# jerameyjames.com

## Project
Jeramey James personal brand / founder signal site. Static HTML — dark terminal aesthetic, JetBrains Mono font. Routes credibility to Tolowa Studio, Konative, SpokaneWire, and Tolowa Pacific.

## Deploy (Google Cloud Run)
- Service: `jerameyjames-com` (project `tolowa-studio`, region `us-west1`, min 0 / max 2 instances)
- Image: `nginxinc/nginx-unprivileged` on port 8080 (`Dockerfile`, `nginx.conf`); unknown paths fall back to `index.html`, `/index.html` redirects to `/`, as Cloudflare Pages did
- Deploys: every push to `main` runs `.github/workflows/deploy.yml` (shared WIF provider `tolowa-studio-github`, deployer SA `jerameyjames-com-deployer@`, runtime SA `jerameyjames-com-runtime@` with no roles)
- One-time setup: `scripts/gcp-provision.sh` (idempotent)
- CI: `.github/workflows/ci.yml` builds the image and smoke-tests it on every PR
- DNS: Bunny (Porkbun is registrar only); apex + `www` point at the Cloud Run domain mapping
- Git: github.com/tolowa-studio/jerameyjames.com
- Production: jerameyjames.com
- Cloudflare and Vercel are prohibited: do not add wrangler config or `vercel.json`

## Stack
Pure HTML/CSS — single `index.html` + images. No build step.

## Files
- `index.html` — full site (52KB)
- `hero.jpg` — 158KB (compressed, q82)
- `portrait.jpg` — 180KB (compressed, q82)

## Next steps (MOTION upgrade per Notion hub §6)
- Install Umami analytics
- Add contact form → Twenty CRM
- Ghost newsletter setup
- Consider upgrading to Next.js when GTM infrastructure is added
