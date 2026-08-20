module.exports = ({ env }) => ({
  host: env('HOST', '0.0.0.0'),
  // Railway injects PORT and its HTTP healthcheck dials the injected port, so the app must
  // honour it rather than pin Strapi's default 1337.
  port: env.int('PORT', 1337),
  app: {
    keys: env.array('APP_KEYS'),
  },
  url: env('URL', ''),
  // Railway terminates TLS at the edge, so trust the proxy headers for absolute URLs.
  proxy: true,
});
