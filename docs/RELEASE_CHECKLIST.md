# Release checklist

## A. Backend (Supabase)
- [ ] All migrations applied (`supabase db push`), including business_reports
- [ ] Run the last query in `supabase/launch_metrics.sql`: every table shows `rowsecurity = true`
- [ ] Dashboard > Database > Advisors (Security): resolve anything flagged
- [ ] Authentication > SMTP Settings: custom SMTP configured (the built-in sender is too limited)
- [ ] Authentication > URL Configuration: `bobp://auth-callback` is in Redirect URLs
- [ ] Authentication > Providers > Email: decide on "Confirm email" (on = safer, needs working SMTP)
- [ ] Authentication > Password settings: minimum length at least 8
- [ ] Edge Function `delete-account` deployed; test with a throwaway account
- [ ] Keepalive workflow added; secrets `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` set; run it once manually
- [ ] Only the publishable key is in the app; the secret/service key is nowhere in the repo

## B. App
- [ ] `lib/core/config/app_config.dart` has your real privacy, deletion and support links
- [ ] Application ID, name, icon, signing, SDK 36: see `docs/ANDROID_RELEASE_SETUP.md`
- [ ] `flutter analyze` and `flutter test` pass
- [ ] Release APK tested on a real phone: register (both types), login, forgot password email -> link opens app,
  book, confirm, complete, dashboard numbers, report a business, delete account

## C. Public pages
- [ ] Fill in the [PLACEHOLDERS] in `docs/privacy-policy.html` and `docs/delete-account.html`
  and have someone sanity-check the policy against what the app really does (I am not a lawyer)
- [ ] Publish them: GitHub repo > Settings > Pages > deploy from branch, folder `/docs`
- [ ] Open both URLs in a browser (no login) and paste them into the app config and Play Console

## D. Demo data for reviewers
- [ ] Register `demo-provider` and `demo-customer` accounts, run `supabase/demo_data.sql`
- [ ] Play Console > App content > App access: choose "restricted access", add both logins

## E. Play Console: app content
- [ ] Create app: name, default language, App (not game), Free, accept declarations
- [ ] Privacy policy URL
- [ ] App access (demo logins above)
- [ ] Ads: **No ads**
- [ ] Content rating questionnaire: no violence, no gambling; users can see other users' content (business listings) -> answer honestly
- [ ] Target audience: 18+ (matches the privacy policy)
- [ ] Data safety form (below)
- [ ] Data deletion: in-app path plus the web URL
- [ ] Government/financial/health app declarations: No
- [ ] Store listing: text from `docs/STORE_LISTING.md`, icon, feature graphic, screenshots

### Data safety answers (based on what the app does today; check each against Google's wording)
| Data | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|
| Name | Yes | No* | App functionality, account management | Required |
| Email address | Yes | No* | App functionality, account management | Required |
| Booking records (service, time, price, status) | Yes (e.g. app activity / user content) | No* | App functionality | Required for booking |
| Report text | Yes (user content) | No* | Safety / moderation | Optional |
- Data encrypted in transit: **Yes** (HTTPS)
- Users can request deletion: **Yes** (in-app + URL)
- No location, contacts, photos, payment info, device IDs, ads or analytics SDKs
- *Supabase and your email provider process data on your behalf as service providers; Google's rules
  generally do not count that as "sharing", but confirm in the form's help text.
- If you later add Firebase, analytics, crash reporting or payments, update this form and the privacy policy.

## F. Testing track (this is the 14-day clock)
- [ ] Release > Testing > Closed testing > create track, upload the `.aab`
- [ ] Add testers (a Google Group or an email list), copy the opt-in link
- [ ] Get **12+ testers opted in and keep them in for 14 days**; ask them to actually use the app
- [ ] Use a few real flows each day yourself; fix crashes shown in Play Console > Android vitals
- [ ] After 14 days, Play Console shows an "Apply for production" step: answer the questions about testing and what you changed
- [ ] Production release > roll out (start at 20% or so if you want a gentle launch)

## G. After launch
- [ ] Run `supabase/launch_metrics.sql` weekly: sign-ups, providers who finished setup, customers who booked
- [ ] Check reports (`business_reports`) and Play Console reviews
- [ ] Keep the upload keystore and passwords backed up
- [ ] Target SDK moves up every August; plan an update each summer
