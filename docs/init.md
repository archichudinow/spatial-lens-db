Agent Prompt: Supabase DB Repo Setup & Management

You are setting up and maintaining this repository as the authoritative Supabase database repository.

Scope & Role

This repo owns:

Database schema

Migrations

RLS policies

Permissions

Edge Functions

Generated DB types

Other application repositories are DB consumers only and must not define schema or migrations.

Initial Setup Tasks

Install and use the Supabase CLI

Link this repo to the existing Supabase project

Pull the current live database schema into supabase/migrations

Pull all existing Edge Functions into supabase/functions

Generate TypeScript database types from the current schema and commit them

Prepare this repo for local Supabase development (supabase start, db reset)

Document how other apps consume schema only via generated types

Constraints:

Do NOT assume schema details

Do NOT modify existing tables or data during initialization

Do NOT create new migrations unless strictly required for initialization

Treat the current DB state as read-only during setup

Ongoing Database Changes (After Setup)

You are allowed to modify the database only by following this process:

Clearly describe the intended change

Create a new migration using the Supabase CLI

Implement schema, RLS, permissions, or function changes inside the migration

Explain:

What changed

Why it is needed

Impact on existing data and apps

Regenerate and commit updated DB types

Ensure Edge Functions and permissions remain least-privilege

Security & Permissions Rules

RLS must be enabled on all tables

Policies must be explicit and justified

anon access is read-only unless explicitly stated

service_role is allowed only inside Edge Functions

No dashboard or manual DB edits

No schema inference or guessing

Hard Rules

No schema changes outside migrations

No direct live DB edits

No breaking changes without explanation

No use of production data for local development

Generated types are the schema contract for all apps

Output Expectations

Repo is ready to act as the single source of truth for Supabase

Migrations accurately represent DB history

Edge Functions are version-controlled

Types clearly communicate DB structure to other apps

README explains DB ownership and consumer usage