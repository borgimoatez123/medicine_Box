# Smart Medicine Dispenser - Backend Server

Backend service for the Smart Medicine Dispenser project, built with Node.js, TypeScript, Express, and Prisma.

## Technology Stack

- **Runtime**: Node.js
- **Language**: TypeScript (strict mode)
- **Web Framework**: Express.js
- **ORM**: Prisma (PostgreSQL / Supabase)
- **Validation**: Zod
- **Authentication**: JWT (jsonwebtoken) + bcrypt
- **Security**: Helmet, CORS
- **Logging**: Morgan
- **Environment**: dotenv
- **Linting**: ESLint + Prettier
- **Testing**: Jest + ts-jest
- **Dev Server**: tsx

## Project Structure

```
src/
├── domain/
│   ├── entities/          # Core domain entities
│   └── repositories/      # Repository interfaces
├── application/
│   └── use-cases/         # Application use cases / business logic
├── infrastructure/
│   ├── database/
│   │   └── prisma/
│   │       ├── repositories/  # Prisma repository implementations
│   │       └── client.ts      # Prisma client instance
│   ├── auth/              # Authentication infrastructure
│   └── ai/                # AI / external integrations
├── presentation/
│   ├── controllers/       # Route handlers / controllers
│   ├── routes/            # Express route definitions
│   ├── middlewares/       # Express middlewares
│   └── validators/        # Zod request validators
├── shared/
│   ├── errors/            # Custom error classes
│   ├── types/             # Shared TypeScript types
│   ├── constants/         # Shared constants
│   └── utils/             # Utility functions
├── app.ts                 # Express app setup
└── server.ts              # HTTP server startup
```

## Getting Started

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment Variables

Copy `.env.example` to `.env` and fill in the values:

```bash
cp .env.example .env
```

Required variables:

| Variable       | Description                                  | Example |
| -------------- | -------------------------------------------- | ------- |
| `NODE_ENV`     | Environment mode (`development`/`production` / `test`) | `development` |
| `PORT`         | Server port                                  | `3000` |
| `DATABASE_URL` | PostgreSQL connection string (Supabase)      | `postgresql://...` |
| `JWT_SECRET`   | Secret key for signing JWTs                  | *(strong random string)* |
| `JWT_EXPIRES_IN` | JWT token expiration time                 | `24h` |
| `CORS_ORIGIN`  | Allowed CORS origin (comma-separated list)   | `http://localhost:5173` |

### 3. Generate Prisma Client

```bash
npm run prisma:generate
```

This generates the TypeScript types and client for your database schema. A database connection is not required for this step (it uses the local schema file).

### 4. Run the Development Server

```bash
npm run dev
```

The server will start with hot-reload via `tsx`.

Health check: `GET http://localhost:3000/health` → `{ "status": "ok" }`

### 5. Build for Production

```bash
npm run build
```

Output is compiled to the `dist/` directory.

### 6. Start Production Server

```bash
npm run start
```

## Scripts

| Command                | Description                                     |
| ---------------------- | ----------------------------------------------- |
| `npm run dev`          | Start development server with hot reload (tsx)  |
| `npm run build`        | Compile TypeScript to `dist/`                   |
| `npm run start`        | Run compiled production server                  |
| `npm run lint`         | Run ESLint (fails on warnings)                  |
| `npm run lint:fix`     | Run ESLint and auto-fix issues                  |
| `npm run format`       | Format source files with Prettier               |
| `npm run format:check` | Check formatting (no writes)                    |
| `npm run test`         | Run Jest tests                                  |
| `npm run test:watch`   | Run Jest in watch mode                          |
| `npm run test:coverage`| Run tests with coverage report                  |
| `npm run prisma:generate` | Generate Prisma client                      |
| `npm run prisma:migrate`  | Create & apply Prisma migration (dev)        |
| `npm run prisma:deploy`   | Deploy pending migrations (production)       |
| `npm run prisma:studio`   | Open Prisma Studio (DB browser)              |
