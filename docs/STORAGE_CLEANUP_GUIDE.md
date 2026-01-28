# Storage Cleanup Guide

## Critical Issue Resolved
The database now tracks which storage files need deletion, but **the frontend must actually delete the files from storage**.

## Implementation Required

### 1. When Resetting/Replacing an Upload

```typescript
// When user clicks [X] to replace model
const { data, error } = await supabase.rpc('reset_option_for_reupload', {
  p_option_id: optionId
})

if (data?.success && data.storage_folder_path) {
  // IMPORTANT: Delete ALL files in the folder, not just tracked ones
  // This handles cases where old upload_files records were cleaned up
  
  // List all files in the folder
  const { data: fileList } = await supabase.storage
    .from('projects')
    .list(data.storage_folder_path)
  
  if (fileList && fileList.length > 0) {
    // Delete all files in the folder
    const pathsToDelete = fileList.map(file => 
      data.storage_folder_path + file.name
    )
    
    const { error: deleteError } = await supabase.storage
      .from('projects')
      .remove(pathsToDelete)
    
    if (deleteError) {
      console.error('Failed to delete storage files:', deleteError)
    } else {
      console.log(`Deleted ${pathsToDelete.length} files from storage`)
    }
  }
}
```

### 2. Periodic Cleanup of Orphaned Files

```typescript
// Run this periodically (e.g., on app startup or admin panel)
async function cleanupOrphanedStorage() {
  // Step 1: Find orphaned files
  const { data: orphaned } = await supabase.rpc('find_orphaned_storage_files')
  
  if (orphaned?.orphaned_files?.length > 0) {
    console.log(`Found ${orphaned.orphaned_files.length} orphaned files`)
    
    // Step 2: Delete from storage
    const paths = orphaned.orphaned_files.map(f => f.path)
    await supabase.storage.from('projects').remove(paths)
    
    // Step 3: Clean up database records
    const { data: cleanup } = await supabase.rpc('cleanup_orphaned_upload_files')
    console.log(cleanup.message)
  }
}

// Call on app mount or in admin panel
cleanupOrphanedStorage()
```

### 3. When Deleting a Project

```typescript
// Before deleting project, get all its storage paths
const { data: paths } = await supabase.rpc('get_project_storage_paths', {
  p_project_id: projectId
})

if (paths) {
  // Delete all storage files for this project
  const storagePaths = paths.map(p => p.storage_path)
  await supabase.storage.from('projects').remove(storagePaths)
}

// Then delete the project (cascade will handle database cleanup)
await supabase.from('projects').delete().eq('id', projectId)
```

## New RPC Functions Available

| Function | Purpose | Returns |
|----------|---------|---------|
| `reset_option_for_reupload(p_option_id)` | Reset completed option for re-upload | Includes `storage_paths_to_delete` |
| `reset_record_for_reupload(p_record_id)` | Reset completed record for re-upload | Includes `storage_paths_to_delete` |
| `find_orphaned_storage_files()` | Find files where parent entity deleted | List of orphaned files |
| `cleanup_orphaned_upload_files()` | Clean database orphaned records | Paths to delete from storage |
| `get_project_storage_paths(p_project_id)` | Get all storage paths for project | All file paths |

## Response Format

```typescript
// reset_option_for_reupload response:
{
  success: true,
  option_id: "...",
  previous_status: "completed",
  new_status: "draft",
  deleted_files_count: 3,
  storage_paths_to_delete: [
    { path: "project_abc/options/123/model_456.glb", type: "model" }
  ],
  message: "Option reset successfully. Delete storage files using the paths provided."
}

// find_orphaned_storage_files response:
{
  success: true,
  orphaned_files: [
    {
      path: "old_project_xyz/options/789/model.glb",
      entity_type: "option",
      entity_id: "...",
      file_type: "model",
      created_at: "2026-01-20T..."
    }
  ],
  message: "Found orphaned files..."
}
```

## Why This Approach?

**Database functions can't directly delete from Supabase Storage** - only client SDKs with proper permissions can. The database tracks what needs deletion, and the frontend executes it.

## Testing Cleanup

```typescript
// Check current orphaned files
const { data } = await supabase.rpc('find_orphaned_storage_files')
console.log(`Orphaned files: ${data.orphaned_files?.length || 0}`)

// Clean them up
if (data.orphaned_files?.length > 0) {
  const paths = data.orphaned_files.map(f => f.path)
  await supabase.storage.from('projects').remove(paths)
  await supabase.rpc('cleanup_orphaned_upload_files')
}
```
