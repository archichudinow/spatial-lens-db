# Spatial Lens Database - Integration Info

**Repository**: https://github.com/archichudinow/spatial-lens-db

## 🔗 Quick Integration

### Database Connection

```typescript
import { createClient } from '@supabase/supabase-js'
import { Database } from './types/database'

const supabase = createClient<Database>(
  'https://piibdadcmkrmvbiapglz.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBpaWJkYWRjbWtybXZiaWFwZ2x6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0MjQyNDgsImV4cCI6MjA4NDAwMDI0OH0.O5GRP3KXTFG2eXDfzZKS1L1q2DoERAt5pklhu5YbvEY'
)
```

### Get Types File

```bash
curl -o src/types/database.ts https://raw.githubusercontent.com/archichudinow/spatial-lens-db/main/supabase/types.ts
```

## 📖 Documentation

- **[CONSUMER_GUIDE.md](https://github.com/archichudinow/spatial-lens-db/blob/main/CONSUMER_GUIDE.md)** - Complete integration guide
- **[README.md](https://github.com/archichudinow/spatial-lens-db/blob/main/README.md)** - Repository overview
- **[IMPLEMENTATION.md](https://github.com/archichudinow/spatial-lens-db/blob/main/IMPLEMENTATION.md)** - Database structure details

## 🌐 Public Access

✅ **Anonymous users can:**
- Read all projects, options, scenarios, records
- Read all storage files
- Submit recordings via Edge Functions:
  - `save-recording` - Server generates GLB
  - `save-recording-with-glb` - Client sends GLB

✅ **Authenticated admins can:**
- Full CRUD on all tables (including direct record insertion)
- Full CRUD on storage files
- Manage project structure

## 📁 Key Resources

| Resource | URL |
|----------|-----|
| **Types File** | https://raw.githubusercontent.com/archichudinow/spatial-lens-db/main/supabase/types.ts |
| **Supabase URL** | https://piibdadcmkrmvbiapglz.supabase.co |
| **Anon Key** | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` |
| **Edge Functions** | https://piibdadcmkrmvbiapglz.supabase.co/functions/v1/ |
| **Storage (Public)** | https://piibdadcmkrmvbiapglz.supabase.co/storage/v1/object/public/projects/ |

## 🚀 Edge Functions

### save-recording
```bash
POST https://piibdadcmkrmvbiapglz.supabase.co/functions/v1/save-recording
```

### save-recording-with-glb
```bash
POST https://piibdadcmkrmvbiapglz.supabase.co/functions/v1/save-recording-with-glb
```

### create-project-complete
```bash
POST https://piibdadcmkrmvbiapglz.supabase.co/functions/v1/create-project-complete
```

### create-option-complete
```bash
POST https://piibdadcmkrmvbiapglz.supabase.co/functions/v1/create-option-complete
```

## 📊 Database Tables

- **projects** - Main project information
- **project_options** - Options for each project (at least one "Base Option")
- **scenarios** - Scenarios for each option (at least one "Base Scenario")
- **records** - User recording data

## 🎯 Quick Examples

### Read Projects
```typescript
const { data: projects } = await supabase
  .from('projects')
  .select('*')
```

### Get Full Project with Options & Scenarios
```typescript
const { data: fullProject } = await supabase
  .from('projects_full')
  .select('*')
  .eq('id', projectId)
  .single()
```

### Get Records for a Scenario
```typescript
const { data: records } = await supabase
  .from('records')
  .select('*')
  .eq('scenario_id', scenarioId)
  .order('created_at', { ascending: false })
```

## 🔄 Keeping Types Updated

Add to your `package.json`:

```json
{
  "scripts": {
    "update-types": "curl -o src/types/database.ts https://raw.githubusercontent.com/archichudinow/spatial-lens-db/main/supabase/types.ts"
  }
}
```

Run: `npm run update-types`
