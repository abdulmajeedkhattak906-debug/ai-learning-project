# CM + AI Health Connect

Mobile-first community mobilizer health dashboard built with React, TypeScript, Vite, Supabase and an installable PWA. It includes English/Urdu RTL layout, activity reporting, campaign/team dashboards, CSV export, browser print-to-PDF, and a bounded health-education assistant.

## Repository inspection
The starting repository contained only a short README and a personal-information text file; there was no application source, dependency setup, tests, or database schema. This project adds a working front-end scaffold and Supabase schema while retaining the existing document. Dashboard figures and named team/activity examples are explicitly illustrative demo content—not official records.

## Run locally

Requirements: Node.js 20+ and npm.

```bash
npm install
npm run dev
```

Open the Vite URL printed in your terminal. `npm run build` runs TypeScript project checks and creates the production bundle in `dist/`; `npm run preview` serves that bundle locally. `npm run typecheck` runs the compiler checks.

## Supabase setup

1. Create a Supabase project and run `supabase/schema.sql` in the SQL Editor.
2. In Authentication settings, configure allowed redirect URLs for localhost and your production domain. Enable email OTP/magic links.
3. Create a `profiles` row for each approved `auth.users` account and assign a least-privilege role (`admin`, `supervisor`, `cm`, `flw`, or `viewer`). For example, an administrator should create profile rows through a trusted process; never allow public signup to self-assign admin.
4. Copy `.env.example` to `.env.local` and set `VITE_SUPABASE_URL` plus the public anon key from Supabase project settings.
5. Restart the dev server. The app loads and saves daily activities when configured. Without those values it uses an in-memory demo and allows local-only activity logging.

Only the Supabase anon/publishable key belongs in this browser app. Never use a service-role key here. RLS is enabled on all schema tables; review the policies against your organization’s data residency, safeguarding, consent, retention, and access-control requirements before entering any real health information. The provided RLS is a baseline—not a substitute for a security review. Child records require additional area-level authorization and auditing for a real deployment; the current baseline restricts them to staff roles but not by assigned UC.

## Features and boundaries

- Responsive dashboard, sidebar navigation, charts, activity log and daily activity form.
- English/Urdu UI toggle, RTL direction for Urdu, mobile navigation, install manifest and service worker caching for the app shell.
- Secure email sign-in link via Supabase Auth when configured; sign-out; activity reads/writes through RLS.
- CSV export for visible activity rows. Use the browser’s Print → Save as PDF for printable reports.
- Assistant responds deterministically to basic polio/EPI information, reporting summaries and follow-up prompts. General polio information links to WHO and UNICEF public pages. It is not a clinical AI model, it does not connect to a generative AI API, and it does not provide diagnosis or individualized medical advice. Confirm current schedules and campaign decisions with official local EPI guidance.
- Campaign, children, follow-up, team, area, sessions, partner and engagement tables are supplied in SQL. Some UI areas are informative module views, not complete CRUD workflows yet. Vaccination record entry and analytics aggregation are deliberately not claimed as implemented.
- Sample dashboard metrics are hard-coded for design demonstration; replace them with verified data queries before operational use. The app does not infer or fabricate child vaccination records.

## Deployment

Build with `npm ci && npm run build`, then deploy the `dist/` directory to a static host such as Cloudflare Pages, Netlify, Vercel, or GitHub Pages (configure SPA fallback to `/index.html`). Set the two `VITE_SUPABASE_*` variables in the host’s build environment. Environment values prefixed with `VITE_` are public client configuration; never put secrets in them. Serve over HTTPS. Confirm the production auth redirect URL, test RLS using separate role accounts, and verify offline behavior on target Android devices before rollout.

## Privacy and clinical safety

Do not put child names, phone numbers, addresses, or other identifying health data into the activity notes. Use the authorized register and approved organizational devices/processes for sensitive data. This software is a project starter, not a certified health-record system. Validate information and workflows with local EPI supervisors and applicable policies before operational use.

## Quality checks

Use `npm run typecheck` and `npm run build` before deployment. No automated end-to-end or database integration suite is included yet; authenticate and exercise create/read activity, sign-out, role access, exports, PWA install, and mobile/RTL layouts in staging before production.
