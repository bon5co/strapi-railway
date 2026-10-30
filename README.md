# strapi-railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/strapi-5-or-just-updated-headless-cms-wh?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

**Deploy on Railway:** [Strapi 5 template](https://railway.com/deploy/strapi-5-or-just-updated-headless-cms-wh?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

Wrapper image for deploying [Strapi 5](https://strapi.io) on
[Railway](https://railway.com), used by the published Railway template.

Image: `ghcr.io/bon5co/strapi-railway:5.52.1`

## What this adds over the upstream scaffold

- **The administrator is seeded before the server binds.** Strapi leaves
  `POST /admin/register-admin` open to any caller until the first administrator
  exists, and nothing in the stock scaffold creates one. On a public URL that
  means the first stranger to load the page owns the CMS. `bin/seed-admin.js`
  runs to completion before the HTTP server starts, so the first request the
  public port ever serves is against a claimed instance.
- **Redeploy is a working password reset.** The seed runs on every boot; if the
  administrator already exists its password is re-applied from
  `STRAPI_ADMIN_PASSWORD`. Strapi's own recovery path is an emailed link, which a
  fresh deploy with no SMTP configuration cannot use.
- **Uploads land on the volume.** Strapi's local upload provider writes to
  `<appRoot>/public/uploads`, which on Railway is `/app/public/uploads` — inside
  the container's disposable layer. The entrypoint links that path onto the
  volume at `/data/uploads`, so media survives a redeploy while the media-library
  rows in Postgres keep pointing at files that still exist.
- **Volume ownership is repaired.** Railway mounts volumes owned by uid 0; the
  image runs the app as uid 1000. The entrypoint chowns the mount as root and
  then drops privileges with `setpriv`.
- **The admin panel is compiled at image build time**, so a deploy is an image
  pull rather than a Node build on the deployer's build minutes.
- **Version pinned** to Strapi 5.52.1. Strapi migrates its schema forward on
  boot with no downgrade path, so a moving tag makes every redeploy an
  unrequested upgrade.
- **SQL query logging off and telemetry disabled.**

## Required environment

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | Postgres connection string |
| `STRAPI_ADMIN_EMAIL` | administrator login |
| `STRAPI_ADMIN_PASSWORD` | administrator password; the container refuses to boot if empty |
| `APP_KEYS` | session keys (comma-separated) |
| `ADMIN_JWT_SECRET`, `API_TOKEN_SALT`, `TRANSFER_TOKEN_SALT`, `ENCRYPTION_KEY`, `JWT_SECRET` | Strapi secrets |

Optional: `STRAPI_ADMIN_FIRSTNAME`, `STRAPI_ADMIN_LASTNAME`, `STRAPI_DATA_DIR`
(defaults to `/data`).

## Volume

Mount the Railway volume at `/data`.
