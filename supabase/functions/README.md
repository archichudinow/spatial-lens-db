# Edge Functions

This directory contains Supabase Edge Functions for the Spatial Lens project.

## Deployed Functions (as of 2026-01-25)

The following Edge Functions are currently deployed on the remote Supabase project:

1. **create-option-complete** (Version 1, Active)
   - Last updated: 2026-01-24 09:20:36 UTC

2. **create-project-complete** (Version 1, Active)
   - Last updated: 2026-01-24 09:21:50 UTC

3. **save-recording** (Version 1, Active)
   - Last updated: 2026-01-24 09:42:37 UTC

4. **save-recording-with-glb** (Version 1, Active)
   - Last updated: 2026-01-24 09:43:11 UTC

## Note

Edge Functions source code needs to be manually added to this directory. The Supabase CLI does not currently support pulling existing Edge Functions from a remote project.

Each function should be in its own subdirectory with an `index.ts` file as the entry point.

Example structure:
```
functions/
├── create-option-complete/
│   └── index.ts
├── create-project-complete/
│   └── index.ts
├── save-recording/
│   └── index.ts
└── save-recording-with-glb/
    └── index.ts
```
