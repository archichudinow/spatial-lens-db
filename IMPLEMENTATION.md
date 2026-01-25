# Database Implementation Verification

This document verifies that all requirements have been implemented correctly.

## ✅ Requirements Checklist

### 1. Auto-create base option and scenario when project is created
- **Trigger**: `trigger_auto_create_base_option` on `projects` table
- **Function**: `auto_create_base_option()`
- **Behavior**: When a new project is inserted, automatically creates:
  - Base option (with `is_default = true`)
  - Base scenario (created by existing trigger on options)

### 2. Auto-create base scenario when option is created
- **Trigger**: `trigger_auto_create_scenario` on `project_options` table (existing)
- **Function**: `auto_create_exploration_scenario()` (existing)
- **Behavior**: When a new option is inserted, automatically creates a base scenario

### 3. Prevent deletion of base option while project exists
- **Trigger**: `trigger_prevent_base_option_deletion` on `project_options` table
- **Function**: `prevent_base_option_deletion()`
- **Behavior**: Raises exception if trying to delete an option where `is_default = true` while the project still exists

### 4. Prevent deletion of base scenario while option exists
- **Trigger**: `trigger_prevent_base_scenario_deletion` on `scenarios` table
- **Function**: `prevent_base_scenario_deletion()`
- **Behavior**: Raises exception if trying to delete the last non-archived scenario for an option

### 5. Cascade delete all related data when project is deleted
- **Trigger**: `trigger_cascade_delete_project` on `projects` table
- **Function**: `cascade_delete_project()`
- **Behavior**: When a project is deleted, automatically deletes:
  - All records in the project
  - All scenarios for all options in the project
  - All options in the project (including base option)

### 6. Storage Structure
- **Bucket**: `projects` (50MB file size limit)
- **Folder structure**:
  ```
  models/option/{option_id}/project_model
  models/option/{option_id}/heatmap_model
  models/context_model
  records/glb/option/{option_id}/scenario/{scenario_id}/{record_id}.glb
  records/raw/option/{option_id}/scenario/{scenario_id}/{record_id}.json
  ```
- **Helper function**: `get_project_storage_path()` for consistent path generation

### 7. RLS Policies - Projects Table
- ✅ `anon` can SELECT (read)
- ✅ `authenticated` can SELECT, INSERT, UPDATE, DELETE
- ❌ `anon` cannot INSERT, UPDATE, DELETE

### 8. RLS Policies - Project Options Table
- ✅ `anon` can SELECT (read)
- ✅ `authenticated` can SELECT, INSERT, UPDATE, DELETE
- ❌ `anon` cannot INSERT, UPDATE, DELETE

### 9. RLS Policies - Scenarios Table
- ✅ `anon` can SELECT (read)
- ✅ `authenticated` can SELECT, INSERT, UPDATE, DELETE
- ❌ `anon` cannot INSERT, UPDATE, DELETE

### 10. RLS Policies - Records Table
- ✅ `anon` can SELECT (read)
- ✅ `service_role` can INSERT (via Edge Functions)
- ✅ `authenticated` can SELECT, UPDATE, DELETE
- ❌ `anon` cannot directly INSERT, UPDATE, DELETE

### 11. Storage Policies
- ✅ `anon` can SELECT (read files)
- ✅ `service_role` can INSERT (upload via Edge Functions)
- ✅ `authenticated` can SELECT, INSERT, UPDATE, DELETE
- ❌ `anon` cannot directly upload, update, or delete files

### 12. Edge Functions Security
- ✅ `save-recording` - Uses `service_role` to insert records
- ✅ `save-recording-with-glb` - Uses `service_role` to upload and insert
- Both functions allow anonymous users to submit data safely through server-side validation

## 🧪 Manual Testing Commands

### Test 1: Create project and verify base option creation
```sql
-- Insert a new project
INSERT INTO projects (name, description, status)
VALUES ('Test Project', 'Testing auto-creation', 'development')
RETURNING *;

-- Verify base option was created (should see one option with is_default = true)
SELECT * FROM project_options WHERE project_id = '<project_id>';

-- Verify base scenario was created (should see one scenario)
SELECT s.* 
FROM scenarios s
JOIN project_options o ON s.option_id = o.id
WHERE o.project_id = '<project_id>';
```

### Test 2: Try to delete base option (should fail)
```sql
-- This should raise an exception
DELETE FROM project_options WHERE is_default = true AND project_id = '<project_id>';
-- Expected error: "Cannot delete base option while project exists"
```

### Test 3: Try to delete base scenario (should fail)
```sql
-- This should raise an exception
DELETE FROM scenarios WHERE option_id = '<option_id>';
-- Expected error: "Cannot delete base scenario. Each option must have at least one scenario."
```

### Test 4: Create additional option and verify scenario creation
```sql
-- Insert a new option
INSERT INTO project_options (project_id, name, description)
VALUES ('<project_id>', 'Option 2', 'Second option')
RETURNING *;

-- Verify scenario was auto-created
SELECT * FROM scenarios WHERE option_id = '<new_option_id>';
```

### Test 5: Delete project and verify cascade
```sql
-- Before deletion, count related records
SELECT 
  (SELECT COUNT(*) FROM project_options WHERE project_id = '<project_id>') as options_count,
  (SELECT COUNT(*) FROM scenarios WHERE option_id IN 
    (SELECT id FROM project_options WHERE project_id = '<project_id>')) as scenarios_count;

-- Delete the project
DELETE FROM projects WHERE id = '<project_id>';

-- Verify all related data is gone
SELECT COUNT(*) FROM project_options WHERE project_id = '<project_id>'; -- Should be 0
SELECT COUNT(*) FROM scenarios WHERE option_id IN 
  (SELECT id FROM project_options WHERE project_id = '<project_id>'); -- Should be 0
```

### Test 6: Verify anon can only read
```sql
-- Set role to anon
SET ROLE anon;

-- This should work
SELECT * FROM projects;

-- This should fail
INSERT INTO projects (name) VALUES ('Anon Project');
-- Expected: permission denied

-- Reset role
RESET ROLE;
```

### Test 7: Verify storage path helper
```sql
SELECT get_project_storage_path(
  '<project_id>'::uuid,
  'record_glb',
  '<option_id>'::uuid,
  '<scenario_id>'::uuid,
  '<record_id>'::uuid
);
-- Should return: records/glb/option/<option_id>/scenario/<scenario_id>/<record_id>.glb
```

## 📊 Database Schema Summary

### Tables
- `projects` - Main project table
- `project_options` - Options for each project (one is always base/default)
- `scenarios` - Scenarios for each option (at least one required)
- `records` - Recording data submitted by users

### Triggers
1. `trigger_auto_create_base_option` - Creates base option when project is created
2. `trigger_auto_create_scenario` - Creates scenario when option is created (existing)
3. `trigger_prevent_base_option_deletion` - Prevents deletion of base option
4. `trigger_prevent_base_scenario_deletion` - Prevents deletion of last scenario
5. `trigger_cascade_delete_project` - Cascades deletion of all related data

### Storage
- Bucket: `projects` (public read, 50MB limit)
- Allowed MIME types: `model/gltf-binary`, `application/octet-stream`, `model/gltf+json`

## 🚀 Deployment Checklist

Before deploying to production:

1. ✅ Test all triggers locally
2. ✅ Verify RLS policies with different roles
3. ✅ Test Edge Functions with anonymous users
4. ✅ Verify storage policies
5. ✅ Regenerate and commit TypeScript types
6. ✅ Review migration for breaking changes
7. ⬜ Deploy migration: `supabase db push`
8. ⬜ Deploy Edge Functions: `supabase functions deploy`
9. ⬜ Verify in production dashboard

## 🔐 Security Summary

### What Anons CAN do:
- ✅ Read all projects, options, scenarios, and records
- ✅ Read all storage files
- ✅ Submit recordings via Edge Functions (which use service_role)

### What Anons CANNOT do:
- ❌ Directly insert, update, or delete database records
- ❌ Directly upload, update, or delete storage files
- ❌ Modify project structure

### What Authenticated Admins CAN do:
- ✅ Full CRUD on all tables
- ✅ Full CRUD on storage files
- ✅ Delete projects (with automatic cascade)
- ❌ Delete base options (while project exists)
- ❌ Delete base scenarios (while option exists)
