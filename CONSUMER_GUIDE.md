# Consuming Database Types in Your App

This guide explains how to use the Spatial Lens database types in your application.

## 📦 Installation Options

### Option 1: Direct File Copy (Recommended for Quick Start)

Download the types file directly:

```bash
curl -o src/types/database.ts https://raw.githubusercontent.com/archichudinow/spatial-lens-db/main/supabase/types.ts
```

### Option 2: Git Submodule (Recommended for Auto-Updates)

Add this repo as a submodule in your project:

```bash
# Add submodule
git submodule add https://github.com/archichudinow/spatial-lens-db.git database-types

# Create symlink or copy
ln -s database-types/supabase/types.ts src/types/database.ts
```

### Option 3: NPM Package (If Published)

```bash
npm install @spatial-lens/database-types
```

## 🔌 Using the Types with Supabase Client

### 1. Install Supabase Client

```bash
npm install @supabase/supabase-js
```

### 2. Create Typed Client

```typescript
import { createClient } from '@supabase/supabase-js'
import { Database } from './types/database'

// Create client with type safety
const supabase = createClient<Database>(
  'https://piibdadcmkrmvbiapglz.supabase.co',
  'YOUR_ANON_KEY'
)

// Now you get full TypeScript autocomplete and type checking!
```

### 3. Querying with Type Safety

```typescript
// Projects - fully typed
const { data: projects, error } = await supabase
  .from('projects')
  .select('*')
// data is typed as Database['public']['Tables']['projects']['Row'][]

// Projects with options and scenarios (using the view)
const { data: fullProjects } = await supabase
  .from('projects_full')
  .select('*')
// Includes nested options and scenarios

// Insert with type checking
const { data: newProject, error } = await supabase
  .from('projects')
  .insert({
    name: 'My Project',
    description: 'Project description',
    status: 'development' // TypeScript ensures this is a valid enum value
  })
  .select()
  .single()

// Type-safe filtering
const { data: records } = await supabase
  .from('records')
  .select('*')
  .eq('project_id', projectId)
  .eq('device_type', 'vr') // TypeScript validates 'vr' | 'pc'
```

### 4. Using Helper Types

```typescript
import { Database } from './types/database'

// Extract specific table types
type Project = Database['public']['Tables']['projects']['Row']
type ProjectInsert = Database['public']['Tables']['projects']['Insert']
type ProjectUpdate = Database['public']['Tables']['projects']['Update']

type Record = Database['public']['Tables']['records']['Row']
type Scenario = Database['public']['Tables']['scenarios']['Row']

// Use in your components/functions
function displayProject(project: Project) {
  console.log(project.name, project.status)
}

function createProject(data: ProjectInsert) {
  return supabase.from('projects').insert(data)
}
```

## 🌐 Public Database Access (No Auth Required)

The database is **publicly readable** for all tables:

```typescript
// No authentication needed for reading!
const supabase = createClient<Database>(
  'https://piibdadcmkrmvbiapglz.supabase.co',
  'YOUR_ANON_KEY' // Public anon key is safe to use
)

// Read projects - works without auth
const { data } = await supabase
  .from('projects')
  .select('*')

// Read records - works without auth
const { data } = await supabase
  .from('records')
  .select('*')
  .eq('project_id', projectId)
```

## 📥 Submitting Recordings (Via Edge Functions)

Anonymous users can submit recordings through Edge Functions:

```typescript
// Submit recording via Edge Function
const response = await fetch(
  'https://piibdadcmkrmvbiapglz.supabase.co/functions/v1/save-recording',
  {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${ANON_KEY}`
    },
    body: JSON.stringify({
      projectId: 'uuid',
      optionId: 'uuid',
      scenarioId: 'uuid',
      optionName: 'Option Name',
      scenarioName: 'Scenario Name',
      deviceType: 'vr', // or 'pc'
      frames: [
        {
          time: 0,
          position: { x: 0, y: 0, z: 0 },
          lookAt: { x: 1, y: 0, z: 0 }
        }
        // ... more frames
      ]
    })
  }
)

const result = await response.json()
console.log('Recording saved:', result)
```

## 🔄 Keeping Types Updated

### Manual Update

```bash
# In your app directory
curl -o src/types/database.ts https://raw.githubusercontent.com/archichudinow/spatial-lens-db/main/supabase/types.ts
```

### Automated Update (package.json)

Add to your `package.json`:

```json
{
  "scripts": {
    "update-types": "curl -o src/types/database.ts https://raw.githubusercontent.com/archichudinow/spatial-lens-db/main/supabase/types.ts",
    "postinstall": "npm run update-types"
  }
}
```

### Git Submodule Update

```bash
git submodule update --remote database-types
```

## 📊 Available Tables

- **projects** - Main project data
- **project_options** - Options for each project
- **scenarios** - Scenarios for each option
- **records** - Recording data from users

## 📋 Available Views

- **projects_full** - Complete project data with nested options and scenarios

## 🔑 Environment Variables

Create a `.env` file in your app:

```env
VITE_SUPABASE_URL=https://piibdadcmkrmvbiapglz.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

Use in your app:

```typescript
const supabase = createClient<Database>(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
)
```

## 🛡️ Security Model

### What You CAN Do (No Auth):
✅ Read all projects, options, scenarios, records  
✅ Read all storage files  
✅ Submit recordings via Edge Functions

### What You CANNOT Do:
❌ Directly insert, update, or delete data  
❌ Modify project structure  
❌ Upload files directly to storage

## 📚 Example Projects

### React/Vite Example

```typescript
// src/lib/supabase.ts
import { createClient } from '@supabase/supabase-js'
import { Database } from '../types/database'

export const supabase = createClient<Database>(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
)

// src/hooks/useProjects.ts
import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { Database } from '../types/database'

type Project = Database['public']['Tables']['projects']['Row']

export function useProjects() {
  const [projects, setProjects] = useState<Project[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function fetchProjects() {
      const { data, error } = await supabase
        .from('projects')
        .select('*')
        .order('created_at', { ascending: false })
      
      if (data) setProjects(data)
      setLoading(false)
    }
    
    fetchProjects()
  }, [])

  return { projects, loading }
}
```

### Next.js Example

```typescript
// lib/database.types.ts
export type { Database } from '../types/database'

// app/projects/page.tsx
import { createClient } from '@supabase/supabase-js'
import type { Database } from '@/types/database'

export default async function ProjectsPage() {
  const supabase = createClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )

  const { data: projects } = await supabase
    .from('projects')
    .select('*')

  return (
    <div>
      {projects?.map(project => (
        <div key={project.id}>
          <h2>{project.name}</h2>
          <p>{project.description}</p>
        </div>
      ))}
    </div>
  )
}
```

## 🆘 Need Help?

- Check the [main README](../README.md) for repository documentation
- Review [IMPLEMENTATION.md](../IMPLEMENTATION.md) for database structure details
- Open an issue in this repository

## 📌 Quick Reference

| Resource | URL |
|----------|-----|
| Types File | `https://raw.githubusercontent.com/archichudinow/spatial-lens-db/main/supabase/types.ts` |
| Supabase URL | `https://piibdadcmkrmvbiapglz.supabase.co` |
| Edge Functions | `https://piibdadcmkrmvbiapglz.supabase.co/functions/v1/` |
| Storage | `https://piibdadcmkrmvbiapglz.supabase.co/storage/v1/object/public/projects/` |
