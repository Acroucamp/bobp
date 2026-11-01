// Deletes the CALLING user's account. The secret key never leaves the server:
// the app only sends the user's own session token.
//
// Deploy:  supabase functions deploy delete-account
// Needs in supabase/config.toml:
//   [functions.delete-account]
//   verify_jwt = false      # the platform check only understands legacy keys;
//                           # withSupabase({ auth: 'user' }) validates the JWT itself
import { withSupabase } from 'npm:@supabase/server@^1';

export default {
  fetch: withSupabase({ auth: 'user' }, async (_req, ctx) => {
    const userId = ctx.userClaims?.id;
    if (!userId) {
      return Response.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // Profile, memberships and (for owners) businesses are removed by the
    // database foreign keys; customer bookings are kept with customer_id = NULL.
    const { error } = await ctx.supabaseAdmin.auth.admin.deleteUser(userId);
    if (error) {
      console.error('deleteUser failed:', error.message);
      return Response.json({ error: 'Could not delete account' }, { status: 500 });
    }

    return Response.json({ ok: true });
  }),
};
