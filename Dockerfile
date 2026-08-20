# Strapi 5 packaged for Railway.
#
# Everything the deployer would otherwise have to build is baked here: dependencies are
# installed and the admin panel is compiled at image build time, so a deploy is a pull
# instead of a Nixpacks build on the deployer's build minutes.
FROM node:22-bookworm-slim

# sharp (image thumbnails) needs libvips at runtime; setpriv drops privileges after the
# entrypoint has repaired the root-owned Railway volume.
RUN apt-get update \
 && apt-get install -y --no-install-recommends libvips42 util-linux ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production \
    STRAPI_TELEMETRY_DISABLED=true \
    STRAPI_DISABLE_UPDATE_NOTIFICATION=true
WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund

COPY config ./config
COPY src ./src
COPY public ./public
COPY bin ./bin
COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

# Compile the admin panel into ./dist and ./build now, not on every deploy.
# Strapi validates required secrets at build time, so supply throwaway values here; the
# real ones arrive from the environment at boot.
RUN APP_KEYS=build,build \
    ADMIN_JWT_SECRET=build \
    API_TOKEN_SALT=build \
    TRANSFER_TOKEN_SALT=build \
    ENCRYPTION_KEY=buildbuildbuildbuildbuildbuild01 \
    JWT_SECRET=build \
    DATABASE_URL=postgres://build:build@127.0.0.1:5432/build \
    npm run build \
 && test -d /app/build

# Strapi's local upload provider writes to <appRoot>/public/uploads. The Railway volume is
# mounted at /data, so the entrypoint links that directory onto the volume; keep a pristine
# copy of whatever the image shipped there so the link never loses the seeded files.
RUN mkdir -p /app/public/uploads && cp -a /app/public/uploads /app/public/uploads.orig

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]

# Strapi writes migrations, caches and temp files under the app root at boot, and the
# container drops to uid 1000 before starting, so hand it the tree it will write to.
RUN mkdir -p /app/database/migrations /app/.tmp /app/.strapi \
 && chown -R node:node /app
