# Personal Coaching Platform MVP

This repo now contains a static front-end starter for a personal coaching system inspired by the public FitFocus product shape:

- landing page: `index.html`
- dashboard demo: `dashboard.html`
- styling: `styles.css`
- content and module data: `script.js`

## What It Includes

- personal-brand landing page
- FitFocus-style product categories adapted for a solo coach
- interactive dashboard navigation
- modules for overview, clients, builder, nutrition, comms, and ops
- responsive layout with no build step required

## Run It Locally

Use any static file server. The simplest option is:

```bash
python3 -m http.server 4173
```

Then open:

- `http://localhost:4173/index.html`
- `http://localhost:4173/dashboard.html`

## Customize The Brand

Open `script.js` and edit the `brand` object near the top:

- `brandName`
- `shortName`
- `coachName`
- `descriptor`

You can also change the visual identity in `styles.css` by updating the CSS variables in `:root`.

## Best Next Build Steps

1. Add auth and persistent client/program data.
2. Model workouts, check-ins, invoices, and messages in a database.
3. Connect payments with Stripe.
4. Convert the client-facing flows into a mobile app or PWA.
