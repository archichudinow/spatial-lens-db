# Storage Cleanup Scripts

## Quick Cleanup

To clean up orphaned storage files and database records:

```bash
# 1. Install dependencies
npm install

# 2. Set your service role key (get from Supabase dashboard)
export SUPABASE_SERVICE_KEY="your-service-role-key-here"

# 3. Run cleanup
npm run cleanup
```

## What Gets Cleaned

The script will:
1. Find all `upload_files` records where the parent entity (option/record/project) no longer exists
2. Delete those files from Supabase Storage (`projects` bucket)
3. Remove the orphaned database records

## Getting Your Service Role Key

1. Go to: https://supabase.com/dashboard/project/piibdadcmkrmvbiapglz/settings/api
2. Copy the `service_role` key (not the `anon` key)
3. Keep it secret - this key has full database access

## Manual Cleanup (Alternative)

If you prefer to run cleanup from your frontend application:

```typescript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

async function cleanupStorage() {
  // Find orphaned files
  const { data } = await supabase.rpc('find_orphaned_storage_files')
  
  if (data?.orphaned_files?.length > 0) {
    // Delete from storage
    const paths = data.orphaned_files.map(f => f.path)
    await supabase.storage.from('projects').remove(paths)
    
    // Clean database
    await supabase.rpc('cleanup_orphaned_upload_files')
  }
}
```

## Scheduling Regular Cleanups

You can schedule this to run periodically:

```bash
# Add to crontab (runs daily at 3am)
0 3 * * * cd /path/to/spatial-lens-db && SUPABASE_SERVICE_KEY=xxx npm run cleanup >> cleanup.log 2>&1
```

Or run it as part of your CI/CD pipeline, or from an admin panel in your app.
