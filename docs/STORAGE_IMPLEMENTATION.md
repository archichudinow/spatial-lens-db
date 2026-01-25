# Storage Update Implementation Guide

## Overview

This document describes the implementation of the hierarchical storage structure defined in STORAGE_UPDATE.md. All project files are now organized in a unified `projects` bucket with a clear hierarchical structure.

## Implementation Summary

### ✅ Completed Changes

1. **Database Schema** (Migration: `20260125161000_add_project_name_field.sql`)
   - Added `get_project_storage_path()` function to generate project folder names
   - Format: `{sanitized_project_name}_{project_id}`

2. **Storage Buckets** (Migration: `20260125162000_consolidate_storage_buckets.sql`)
   - Consolidated to single `projects` bucket (500MB limit)
   - Created hierarchical path generation functions:
     - `generate_option_model_path()` - Option 3D models
     - `generate_record_glb_path()` - Processed recordings
     - `generate_record_raw_path()` - Raw recording data
     - `generate_project_other_path()` - Context/heatmap files
   - Updated storage policies for service_role access

3. **Edge Functions Updated**
   - `save-recording-with-glb/index.ts` - Uses hierarchical paths
   - `save-recording/index.ts` - Uses hierarchical paths

4. **Client Utilities** (`supabase/storage-utils.ts`)
   - TypeScript utilities for client-side path generation
   - Path parsing and validation functions
   - Usage examples included

## Storage Structure

```
projects/
  {project_name}_{project_id}/
    options/
      {option_id}/
        model_1234567890.glb
    
    records/
      records_glb/
        {option_id}/
          {scenario_id}/
            processed_recording_1234567890.glb
      
      records_csv/
        {option_id}/
          {scenario_id}/
            raw_recording_1234567890.json
    
    others/
      context_1234567890.glb
      heatmap_1234567891.glb
```

## How to Use

### Server-Side (Edge Functions)

Edge functions use database RPC calls to generate paths:

```typescript
// Get project storage path
const { data: projectPath } = await supabaseClient
  .rpc('get_project_storage_path', { project_id: projectId })
// Returns: "spatial_analysis_abc-123"

// Generate recording path
const { data: glbPath } = await supabaseClient
  .rpc('generate_record_glb_path', {
    p_project_id: projectId,
    p_option_id: optionId,
    p_scenario_id: scenarioId,
    p_timestamp: Date.now()
  })
// Returns: "spatial_analysis_abc-123/records/records_glb/def-456/ghi-789/processed_recording_1234567890.glb"

// Upload file
await supabaseClient.storage
  .from('projects')
  .upload(glbPath, fileData, { contentType: 'model/gltf-binary' })
```

### Client-Side (TypeScript)

Use the utilities in `supabase/storage-utils.ts`:

```typescript
import { generateStoragePath, StorageContext } from './supabase/storage-utils'

const context: StorageContext = {
  projectId: 'abc-123',
  projectName: 'Spatial Analysis',
  optionId: 'def-456',
  scenarioId: 'ghi-789'
}

// Generate paths
const { bucket, path } = generateStoragePath('record', 'processed_recording', context)

// Note: Actual upload must go through Edge Functions due to storage policies
// Client code generates paths for preview/validation only
```

### Upload Through Edge Functions

Clients must upload files via Edge Functions (not directly to storage):

```typescript
// Prepare form data
const formData = new FormData()
formData.append('projectId', projectId)
formData.append('optionId', optionId)
formData.append('scenarioId', scenarioId)
formData.append('glbFile', glbFile)
formData.append('csvFile', csvFile)

// Call edge function
const response = await fetch('/functions/v1/save-recording-with-glb', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${supabaseAnonKey}`
  },
  body: formData
})
```

## Migration Steps

### For New Projects

Simply run the migrations in order:
```bash
supabase db reset
```

### For Existing Projects with Data

1. **Backup existing data**
   ```sql
   -- Backup projects table
   CREATE TABLE projects_backup AS SELECT * FROM projects;
   
   -- Backup storage references
   SELECT * FROM storage.objects WHERE bucket_id IN ('models', 'recordings', 'projects');
   ```

2. **Run migrations**
   ```bash
   supabase db push
   ```

3. **Migrate existing storage files** (manual process)
   - Download files from old paths
   - Re-upload through Edge Functions to new paths
   - Update database records with new URLs

4. **Clean up old buckets** (optional, after verification)
   ```sql
   -- After migrating all files
   DELETE FROM storage.objects WHERE bucket_id IN ('models', 'recordings');
   DELETE FROM storage.buckets WHERE id IN ('models', 'recordings');
   ```

## Storage Policies

All storage operations use service_role for security:

- ✅ Public/Anon can **READ** from `projects` bucket
- ✅ Service role can **INSERT/UPDATE/DELETE**
- ❌ Direct client uploads are **blocked**

This ensures:
- All uploads go through validation in Edge Functions
- Consistent path generation
- Proper database record creation
- File cleanup on errors

## Benefits of This Structure

1. **Organization**: All project files grouped together
2. **Readability**: Folder names include project names
3. **Scalability**: Clear hierarchy prevents collisions
4. **Debuggability**: Easy to locate files in storage browser
5. **Flexibility**: Easy to download/backup entire projects
6. **Security**: Centralized upload validation

## Troubleshooting

### Path Generation Errors

If path generation fails, check:
1. Project exists in database
2. Project has a valid name field
3. All required IDs (optionId, scenarioId) are provided

### Upload Failures

If uploads fail:
1. Verify Edge Function is using service_role key
2. Check file size limits (500MB max)
3. Verify MIME types are allowed
4. Check Edge Function logs for detailed errors

### Path Parsing Issues

Use the `parseStoragePath()` utility to debug paths:
```typescript
import { parseStoragePath } from './supabase/storage-utils'

const parsed = parseStoragePath('spatial_analysis_abc-123/records/records_glb/def-456/ghi-789/processed_recording_1234567890.glb')
console.log(parsed)
// { projectName: 'spatial_analysis', projectId: 'abc-123', category: 'records', ... }
```

## Next Steps

- [ ] Update any existing client code to use Edge Functions for uploads
- [ ] Migrate existing files to new structure (if applicable)
- [ ] Update documentation/API references
- [ ] Test all upload scenarios
- [ ] Clean up old storage buckets (after migration)
