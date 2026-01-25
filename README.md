# Spatial Lens Database

**The authoritative source of truth for the Spatial Lens Supabase database.**

## 🎯 Repository Purpose

This repository **owns and manages** all database-related concerns for the Spatial Lens project:

- ✅ Database schema definitions
- ✅ Migration history
- ✅ Row Level Security (RLS) policies
- ✅ Database permissions and roles
- ✅ Edge Functions
- ✅ TypeScript type definitions generated from the database

**All other application repositories are database consumers only** and must not define schema or migrations.

## 📋 Table of Contents

- [Database Ownership Model](#database-ownership-model)
- [Getting Started](#getting-started)
- [Local Development](#local-development)
- [Making Database Changes](#making-database-changes)
- [Consuming Database Types](#consuming-database-types)
- [Edge Functions](#edge-functions)
- [Security & Permissions](#security--permissions)

## 🏛️ Database Ownership Model

### This Repo Owns
- Schema definitions (tables, views, functions)
- All database migrations
- RLS policies and security rules
- Database permissions and roles
- Edge Functions source code
- Generated TypeScript types

### Consumer Apps Use
- Generated types from `supabase/types.ts`
- Supabase client libraries for data access
- Edge Function endpoints (deployed)

**Important:** Consumer applications should **never** create their own migrations or modify the database schema directly.

## 🚀 Getting Started

### Prerequisites

- [Supabase CLI](https://supabase.com/docs/guides/cli) installed
- Docker Desktop running (for local development)
- Access to the Supabase project

### Initial Setup

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd spatial-lens-db
   ```

2. **Login to Supabase**
   ```bash
   supabase login
   ```

3. **Verify project link**
   ```bash
   supabase link --project-ref piibdadcmkrmvbiapglz
   ```

## 💻 Local Development

### Start Local Supabase

```bash
supabase start
```

This will:
- Start all Supabase services locally (Database, Auth, Storage, Edge Functions, etc.)
- Apply all migrations from `supabase/migrations/`
- Seed the database with test data from `supabase/seed.sql`
- Provide local URLs for Studio, APIs, and database

Access Supabase Studio: `http://127.0.0.1:54323`

### Reset Database

To reset your local database to a clean state:

```bash
supabase db reset
```

This applies all migrations and seeds fresh.

### Stop Local Supabase

```bash
supabase stop
```

## 🔄 Making Database Changes

### Creating a New Migration

**Never modify the database directly.** All changes must go through migrations.

1. **Describe the change clearly** before starting

2. **Create a new migration**
   ```bash
   supabase migration new <descriptive_name>
   ```

3. **Implement the change** in the generated SQL file
   - Schema changes (CREATE, ALTER, DROP)
   - RLS policies
   - Functions and triggers
   - Permissions

4. **Test locally**
   ```bash
   supabase db reset
   # Verify your changes work
   ```

5. **Regenerate TypeScript types**
   ```bash
   supabase gen types typescript --linked > supabase/types.ts
   ```

6. **Commit everything**
   ```bash
   git add supabase/migrations/ supabase/types.ts
   git commit -m "feat: <description of change>"
   ```

7. **Deploy to remote**
   ```bash
   supabase db push
   ```

### Migration Best Practices

- ✅ One logical change per migration
- ✅ Include both schema and RLS policies
- ✅ Add comments explaining complex logic
- ✅ Test with `supabase db reset` before committing
- ✅ Never edit existing migrations (create a new one to fix)
- ❌ No breaking changes without coordination
- ❌ No manual database edits via dashboard

## 📦 Consuming Database Types

Other applications should consume the database schema via the generated TypeScript types.

### For TypeScript/JavaScript Applications

1. **Copy types to your project** (or use as a git submodule)
   ```bash
   cp path/to/spatial-lens-db/supabase/types.ts src/types/database.ts
   ```

2. **Use with Supabase client**
   ```typescript
   import { createClient } from '@supabase/supabase-js'
   import { Database } from './types/database'

   const supabase = createClient<Database>(
     process.env.SUPABASE_URL!,
     process.env.SUPABASE_ANON_KEY!
   )

   // Now you get full type safety
   const { data } = await supabase
     .from('projects')
     .select('*')
   ```

### Keeping Types in Sync

Consumer apps should update their local copy of `types.ts` whenever this repository's types change:

```bash
# In consumer app
npm run update-db-types
```

Create a script in consumer's `package.json`:
```json
{
  "scripts": {
    "update-db-types": "curl -o src/types/database.ts https://raw.githubusercontent.com/archichudinow/spatial-lens-db/main/supabase/types.ts"
  }
}
```

## ⚡ Edge Functions

Edge Functions are located in `supabase/functions/`.

### Currently Deployed Functions

- `create-option-complete` - Creates a new project option
- `create-project-complete` - Creates a new project with full setup
- `save-recording` - Saves recording data
- `save-recording-with-glb` - Saves recording with GLB model file

### Deploying Functions

```bash
# Deploy a specific function
supabase functions deploy <function-name>

# Deploy all functions
supabase functions deploy
```

### Testing Functions Locally

```bash
supabase functions serve <function-name>
```

## 🔒 Security & Permissions

### RLS (Row Level Security)

**All tables must have RLS enabled.** No exceptions.

```sql
ALTER TABLE your_table ENABLE ROW LEVEL SECURITY;

-- Then create explicit policies
CREATE POLICY "Users can read their own data"
  ON your_table FOR SELECT
  USING (auth.uid() = user_id);
```

### Access Levels

- **`anon` role**: Read-only access (public data only)
- **`authenticated` role**: Read/write per RLS policies
- **`service_role`**: Full access (use only in Edge Functions, never exposed to client)

### Security Rules

1. ✅ All tables have RLS enabled
2. ✅ Policies are explicit and justified
3. ✅ `anon` is read-only unless specifically needed
4. ✅ `service_role` only in Edge Functions
5. ❌ Never expose service_role key to clients
6. ❌ No wildcard policies without security checks

## 📚 Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Supabase CLI Reference](https://supabase.com/docs/reference/cli)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## 🤝 Contributing

When making database changes:

1. Create a descriptive issue explaining the change
2. Create a new migration (never edit existing ones)
3. Update types and commit together
4. Test locally with `supabase db reset`
5. Document breaking changes
6. Coordinate with consumer app teams

## 📝 License

[Your License Here]
  To upgrade:

  ```sh
  brew upgrade supabase
  ```
</details>

<details>
  <summary><b>Windows</b></summary>

  Available via [Scoop](https://scoop.sh). To install:

  ```powershell
  scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
  scoop install supabase
  ```

  To upgrade:

  ```powershell
  scoop update supabase
  ```
</details>

<details>
  <summary><b>Linux</b></summary>

  Available via [Homebrew](https://brew.sh) and Linux packages.

  #### via Homebrew

  To install:

  ```sh
  brew install supabase/tap/supabase
  ```

  To upgrade:

  ```sh
  brew upgrade supabase
  ```

  #### via Linux packages

  Linux packages are provided in [Releases](https://github.com/supabase/cli/releases). To install, download the `.apk`/`.deb`/`.rpm`/`.pkg.tar.zst` file depending on your package manager and run the respective commands.

  ```sh
  sudo apk add --allow-untrusted <...>.apk
  ```

  ```sh
  sudo dpkg -i <...>.deb
  ```

  ```sh
  sudo rpm -i <...>.rpm
  ```

  ```sh
  sudo pacman -U <...>.pkg.tar.zst
  ```
</details>

<details>
  <summary><b>Other Platforms</b></summary>

  You can also install the CLI via [go modules](https://go.dev/ref/mod#go-install) without the help of package managers.

  ```sh
  go install github.com/supabase/cli@latest
  ```

  Add a symlink to the binary in `$PATH` for easier access:

  ```sh
  ln -s "$(go env GOPATH)/bin/cli" /usr/bin/supabase
  ```

  This works on other non-standard Linux distros.
</details>

<details>
  <summary><b>Community Maintained Packages</b></summary>

  Available via [pkgx](https://pkgx.sh/). Package script [here](https://github.com/pkgxdev/pantry/blob/main/projects/supabase.com/cli/package.yml).
  To install in your working directory:

  ```bash
  pkgx install supabase
  ```

  Available via [Nixpkgs](https://nixos.org/). Package script [here](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/tools/supabase-cli/default.nix).
</details>

### Run the CLI

```bash
supabase bootstrap
```

Or using npx:

```bash
npx supabase bootstrap
```

The bootstrap command will guide you through the process of setting up a Supabase project using one of the [starter](https://github.com/supabase-community/supabase-samples/blob/main/samples.json) templates.

## Docs

Command & config reference can be found [here](https://supabase.com/docs/reference/cli/about).

## Breaking changes

We follow semantic versioning for changes that directly impact CLI commands, flags, and configurations.

However, due to dependencies on other service images, we cannot guarantee that schema migrations, seed.sql, and generated types will always work for the same CLI major version. If you need such guarantees, we encourage you to pin a specific version of CLI in package.json.

## Developing

To run from source:

```sh
# Go >= 1.22
go run . help
```
