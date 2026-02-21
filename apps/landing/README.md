# Getting Started with the Monorepo

This project is a monorepo managed by **Turborepo**.

## Project Structure

- `apps/mobile`: The Flutter mobile application.
- `apps/landing`: The Next.js landing page.
- `docs`: Detailed documentation and implementation guides.

## Prerequisites

- Node.js `18+`
- Flutter SDK `3.x`
- npm or yarn

## Installation

```bash
# Install root dependencies
npm install

# Install Flutter dependencies
cd apps/mobile
flutter pub get
```

## Running the Applications

From the root directory:

```bash
# Run both applications in development mode
npm run dev

# Run only the landing page
npm run dev -- --filter=landing

# Run only the mobile app (requires a device/emulator)
cd apps/mobile
flutter run
```

## Common Scripts

- `npm run dev`: Starts all apps in development mode.
- `npm run build`: Builds all apps for production.
- `npm run lint`: Runs linting for all workspace packages.
