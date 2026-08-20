'use strict';

/**
 * Create the Strapi super administrator, or re-apply its password if it already exists.
 *
 * Strapi ships no way to seed an administrator from the environment: `/admin/register-admin`
 * stays open to any caller until the first admin row exists, and the CLI's
 * `admin:create-user` exits non-zero once it does. Running this before the HTTP server binds
 * means the public URL is never served while the instance is unclaimed, and running it on
 * every boot makes a redeploy a working password reset — the only recovery path an instance
 * with no SMTP configuration has.
 */

const { compileStrapi, createStrapi } = require('@strapi/strapi');

const email = (process.env.STRAPI_ADMIN_EMAIL || '').trim();
const password = process.env.STRAPI_ADMIN_PASSWORD || '';
const firstname = (process.env.STRAPI_ADMIN_FIRSTNAME || 'Admin').trim();
const lastname = (process.env.STRAPI_ADMIN_LASTNAME || 'User').trim();

if (!email || !password) {
  console.error('[seed-admin] STRAPI_ADMIN_EMAIL and STRAPI_ADMIN_PASSWORD are required.');
  process.exit(1);
}

async function main() {
  const appContext = await compileStrapi();
  // load() runs register() and bootstrap(); bootstrap() syncs the database schema, so the
  // admin tables exist by the time this returns.
  const app = await createStrapi(appContext).load();

  try {
    const userService = app.service('admin::user');
    const roleService = app.service('admin::role');

    const existing = await userService.findOneByEmail(email);

    if (existing) {
      await userService.resetPasswordByEmail(email, password);
      console.log(`[seed-admin] re-applied password for existing administrator ${email}`);
    } else {
      const superAdmin = await roleService.getSuperAdmin();
      if (!superAdmin) {
        throw new Error('super admin role is missing; refusing to seed');
      }
      await userService.create({
        email,
        firstname,
        lastname,
        isActive: true,
        registrationToken: null,
        roles: [superAdmin.id],
        password,
      });
      console.log(`[seed-admin] created super administrator ${email}`);
    }
  } finally {
    // Strapi's admin metrics service issues a detached telemetry query after a user is
    // created; once the pool is torn down it rejects with a 60s Knex acquire timeout, and an
    // unhandled rejection would exit non-zero AFTER the administrator was already seeded,
    // failing the boot. The seed is committed by this point, so downgrade it to a warning.
    process.on('unhandledRejection', (err) => {
      console.warn('[seed-admin] ignoring post-seed rejection:', err && err.message ? err.message : err);
    });

    try {
      await app.destroy();
    } catch (err) {
      // ignore teardown errors: the seed itself has already committed
    }
  }

  // Strapi's admin metrics service issues a fire-and-forget query after user creation. Once
  // destroy() has closed the pool that query rejects, and an unhandled rejection here would
  // fail the whole boot after the administrator was already seeded. Exit on our own terms.
  process.exit(0);
}

main().catch((err) => {
  console.error('[seed-admin] failed:', err && err.message ? err.message : err);
  process.exit(1);
});
