# Upload Pipeline Design

**Date:** January 25, 2026  
**Status:** Design Document  
**Purpose:** Define safe, consistent multi-phase upload flow for spatial-lens-db

---

## 📋 Executive Summary

This document defines a complete redesign of the upload pipeline to support safe, async file uploads with proper state management, validation, and recovery mechanisms.

**Key Principles:**
- Database enforces lifecycle states and prevents invalid transitions
- Files can only be uploaded after metadata exists
- Records cannot be marked complete without required files
- Failed uploads are recoverable without corrupting data
- Client has clear contracts and responsibilities

---

## 1️⃣ Database Schema Design

### A. Upload Status Enum

Create a new enum type to track entity upload lifecycle:

```sql
CREATE TYPE upload_status AS ENUM (
  'draft',      -- Metadata created, no uploads started
  'uploading',  -- Files are being uploaded
  'completed',  -- All required files validated and linked
  'failed'      -- Upload or processing failed, recoverable
);
```

### B. Modified Tables

#### **projects** table
- Add `upload_status` column (applies to projects with context models)
- Add `required_files` JSONB to track what files are needed
- Add `uploaded_files` JSONB to track what files exist

```sql
ALTER TABLE projects ADD COLUMN upload_status upload_status DEFAULT 'draft';
ALTER TABLE projects ADD COLUMN required_files JSONB DEFAULT '[]'::jsonb;
ALTER TABLE projects ADD COLUMN uploaded_files JSONB DEFAULT '[]'::jsonb;
```

#### **project_options** table
- Add `upload_status` column (for model_url)
- Add `model_file_size` for validation
- Add `model_uploaded_at` timestamp

```sql
ALTER TABLE project_options ADD COLUMN upload_status upload_status DEFAULT 'draft';
ALTER TABLE project_options ADD COLUMN model_file_size BIGINT;
ALTER TABLE project_options ADD COLUMN model_uploaded_at TIMESTAMP WITH TIME ZONE;
```

#### **records** table (PRIMARY FOCUS)
- Add `upload_status` column
- Make `raw_url` and `record_url` nullable during upload
- Add validation constraints for completed state
- Add file metadata

```sql
ALTER TABLE records ADD COLUMN upload_status upload_status DEFAULT 'draft';
ALTER TABLE records ADD COLUMN raw_file_size BIGINT;
ALTER TABLE records ADD COLUMN record_file_size BIGINT;
ALTER TABLE records ADD COLUMN raw_uploaded_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE records ADD COLUMN record_uploaded_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE records ADD COLUMN upload_error TEXT;
ALTER TABLE records ADD COLUMN upload_retry_count INTEGER DEFAULT 0;

-- Allow nullable URLs during upload
ALTER TABLE records ALTER COLUMN raw_url DROP NOT NULL;
ALTER TABLE records ALTER COLUMN record_url DROP NOT NULL;
```

### C. New Table: upload_files

Track individual files and their association with parent entities:

```sql
CREATE TABLE upload_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Parent entity reference (polymorphic)
  entity_type TEXT NOT NULL CHECK (entity_type IN ('project', 'option', 'record')),
  entity_id UUID NOT NULL,
  
  -- File metadata
  file_type TEXT NOT NULL CHECK (file_type IN ('model', 'raw_recording', 'processed_recording', 'context_model', 'heatmap')),
  file_path TEXT NOT NULL, -- Storage path
  file_size BIGINT,
  mime_type TEXT,
  
  -- Upload tracking
  upload_status upload_status DEFAULT 'uploading',
  uploaded_at TIMESTAMP WITH TIME ZONE,
  verified_at TIMESTAMP WITH TIME ZONE,
  
  -- Metadata
  metadata JSONB DEFAULT '{}'::jsonb,
  is_required BOOLEAN DEFAULT true,
  
  -- Audit
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE,
  
  -- Ensure file paths are unique
  UNIQUE(file_path)
);

CREATE INDEX idx_upload_files_entity ON upload_files(entity_type, entity_id);
CREATE INDEX idx_upload_files_status ON upload_files(upload_status);
CREATE INDEX idx_upload_files_type ON upload_files(file_type);
```

### D. Constraints & Checks

#### Check function: validate_completion

```sql
CREATE OR REPLACE FUNCTION validate_entity_completion()
RETURNS TRIGGER AS $$
DECLARE
  required_count INTEGER;
  completed_count INTEGER;
BEGIN
  -- Only validate when transitioning TO completed
  IF NEW.upload_status = 'completed' AND OLD.upload_status != 'completed' THEN
    
    -- For records: ensure raw_url and record_url exist
    IF TG_TABLE_NAME = 'records' THEN
      IF NEW.record_url IS NULL THEN
        RAISE EXCEPTION 'Cannot mark record as completed: record_url is required';
      END IF;
      
      -- Check that files exist in upload_files table
      SELECT COUNT(*) INTO completed_count
      FROM upload_files
      WHERE entity_type = 'record'
        AND entity_id = NEW.id
        AND is_required = true
        AND upload_status = 'completed';
      
      SELECT COUNT(*) INTO required_count
      FROM upload_files
      WHERE entity_type = 'record'
        AND entity_id = NEW.id
        AND is_required = true;
      
      IF required_count > 0 AND completed_count < required_count THEN
        RAISE EXCEPTION 'Cannot mark record as completed: only % of % required files uploaded',
          completed_count, required_count;
      END IF;
    END IF;
    
    -- Similar checks for project_options
    IF TG_TABLE_NAME = 'project_options' THEN
      IF NEW.model_url IS NOT NULL AND NEW.model_file_size IS NULL THEN
        RAISE EXCEPTION 'Cannot mark option as completed: model file not verified';
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach to tables
CREATE TRIGGER validate_records_completion
  BEFORE UPDATE ON records
  FOR EACH ROW
  EXECUTE FUNCTION validate_entity_completion();

CREATE TRIGGER validate_options_completion
  BEFORE UPDATE ON project_options
  FOR EACH ROW
  EXECUTE FUNCTION validate_entity_completion();
```

#### Check function: prevent_invalid_transitions

```sql
CREATE OR REPLACE FUNCTION validate_status_transition()
RETURNS TRIGGER AS $$
BEGIN
  -- Prevent invalid transitions
  IF OLD.upload_status IS NOT NULL AND NEW.upload_status != OLD.upload_status THEN
    
    -- draft -> uploading, failed: OK
    -- uploading -> completed, failed: OK
    -- completed -> (any): NOT OK (immutable once completed)
    -- failed -> uploading, draft: OK (retry)
    
    IF OLD.upload_status = 'completed' THEN
      RAISE EXCEPTION 'Cannot change status from completed to %', NEW.upload_status;
    END IF;
    
    IF OLD.upload_status = 'draft' AND NEW.upload_status NOT IN ('uploading', 'failed') THEN
      RAISE EXCEPTION 'Invalid transition from draft to %', NEW.upload_status;
    END IF;
    
    IF OLD.upload_status = 'uploading' AND NEW.upload_status NOT IN ('completed', 'failed') THEN
      RAISE EXCEPTION 'Invalid transition from uploading to %', NEW.upload_status;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_records_status_transition
  BEFORE UPDATE ON records
  FOR EACH ROW
  EXECUTE FUNCTION validate_status_transition();
  
CREATE TRIGGER validate_options_status_transition
  BEFORE UPDATE ON project_options
  FOR EACH ROW
  EXECUTE FUNCTION validate_status_transition();
```

---

## 2️⃣ Status Transition Diagram

```
┌─────────┐
│  draft  │  ← Initial state when metadata created
└────┬────┘
     │
     │ start upload
     ↓
┌───────────┐
│ uploading │  ← Files being uploaded
└─────┬─────┘
      │
      ├───→ all files uploaded & validated ───→ ┌───────────┐
      │                                          │ completed │ (FINAL)
      │                                          └───────────┘
      │
      └───→ error occurred ──────────────────→ ┌─────────┐
                                                │ failed  │
                                                └────┬────┘
                                                     │
                                                     │ retry
                                                     ↓
                                              ┌───────────┐
                                              │ uploading │
                                              └───────────┘
```

### Allowed Transitions

| From       | To         | Condition                           |
|------------|------------|-------------------------------------|
| draft      | uploading  | First file upload initiated         |
| draft      | failed     | Validation failed before upload     |
| uploading  | completed  | All required files verified         |
| uploading  | failed     | Upload error occurred               |
| failed     | uploading  | Retry initiated                     |
| failed     | draft      | Reset to initial state (rare)       |

### Forbidden Transitions

| From       | To         | Reason                              |
|------------|------------|-------------------------------------|
| completed  | ANY        | Completed state is immutable        |
| draft      | completed  | Must go through uploading phase     |
| uploading  | draft      | Cannot go backwards during upload   |

---

## 3️⃣ Supabase Storage Strategy

### A. Bucket Structure

Create dedicated buckets with appropriate policies:

```sql
-- Storage buckets (create via Supabase dashboard or SQL)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('recordings', 'recordings', false, 524288000, ARRAY['application/json', 'model/gltf-binary', 'application/octet-stream']),
  ('models', 'models', true, 104857600, ARRAY['model/gltf-binary', 'model/gltf+json', 'application/octet-stream']),
  ('projects', 'projects', true, 104857600, ARRAY['model/gltf-binary', 'model/gltf+json', 'application/octet-stream']);
```

### B. File Naming Convention

**Format:** `{entity_type}/{entity_id}/{file_type}_{timestamp}.{ext}`

Examples:
- `records/123e4567-e89b-12d3-a456-426614174000/raw_1737820800000.json`
- `records/123e4567-e89b-12d3-a456-426614174000/processed_1737820800000.glb`
- `options/987fcdeb-51a2-43f7-b123-426614174000/model_1737820800000.glb`

**Benefits:**
- Easy to associate files with entities
- Unique timestamps prevent collisions
- Clear file type identification
- Supports multiple versions

### C. Storage Policies

```sql
-- Recordings bucket: authenticated users can upload, anyone can read their recordings
CREATE POLICY "Authenticated users can upload recordings"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'recordings');

CREATE POLICY "Users can read recordings they created"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'recordings');

-- Public read for released projects (via path pattern)
CREATE POLICY "Public can read recordings for released projects"
ON storage.objects FOR SELECT
TO anon
USING (
  bucket_id = 'recordings' 
  AND EXISTS (
    SELECT 1 FROM records r
    JOIN projects p ON p.id = r.project_id
    WHERE p.status = 'released'
    AND storage.objects.name LIKE 'records/' || r.id::text || '%'
  )
);

-- Models bucket: authenticated upload, public read
CREATE POLICY "Authenticated users can upload models"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'models');

CREATE POLICY "Public can read models"
ON storage.objects FOR SELECT
USING (bucket_id = 'models');
```

### D. Upload Flow Integration

**Step 1: Create metadata row**
```sql
INSERT INTO records (project_id, option_id, scenario_id, device_type, upload_status)
VALUES ($1, $2, $3, $4, 'draft')
RETURNING id;
```

**Step 2: Generate signed upload URLs**
```typescript
// Create upload_files entries first
const { data: fileRecords } = await supabase
  .from('upload_files')
  .insert([
    {
      entity_type: 'record',
      entity_id: recordId,
      file_type: 'raw_recording',
      file_path: `records/${recordId}/raw_${Date.now()}.json`,
      is_required: false
    },
    {
      entity_type: 'record',
      entity_id: recordId,
      file_type: 'processed_recording',
      file_path: `records/${recordId}/processed_${Date.now()}.glb`,
      is_required: true
    }
  ])
  .select();

// Generate signed URLs for uploads
const signedUrls = await Promise.all(
  fileRecords.map(file => 
    supabase.storage
      .from('recordings')
      .createSignedUploadUrl(file.file_path)
  )
);
```

**Step 3: Update status to uploading**
```sql
UPDATE records 
SET upload_status = 'uploading'
WHERE id = $1;
```

**Step 4: Upload files to signed URLs**
```typescript
// Client uploads files
await fetch(signedUrl, {
  method: 'PUT',
  body: fileBlob,
  headers: { 'Content-Type': mimeType }
});
```

**Step 5: Verify and mark files complete**
```typescript
// After each successful upload
await supabase
  .from('upload_files')
  .update({
    upload_status: 'completed',
    uploaded_at: new Date().toISOString(),
    file_size: fileBlob.size,
    mime_type: fileBlob.type
  })
  .eq('id', fileRecordId);
```

**Step 6: Finalize record**
```typescript
// Call finalization endpoint
await supabase.rpc('finalize_record', { record_id: recordId });
```

```sql
CREATE OR REPLACE FUNCTION finalize_record(record_id UUID)
RETURNS JSON AS $$
DECLARE
  required_count INTEGER;
  completed_count INTEGER;
  file_data JSON;
BEGIN
  -- Check all required files are completed
  SELECT 
    COUNT(*) FILTER (WHERE is_required) as required,
    COUNT(*) FILTER (WHERE is_required AND upload_status = 'completed') as completed
  INTO required_count, completed_count
  FROM upload_files
  WHERE entity_type = 'record' AND entity_id = record_id;
  
  IF required_count > completed_count THEN
    RAISE EXCEPTION 'Cannot finalize: % of % required files not completed', 
      (required_count - completed_count), required_count;
  END IF;
  
  -- Get file URLs
  SELECT json_agg(json_build_object(
    'type', file_type,
    'url', file_path,
    'size', file_size
  )) INTO file_data
  FROM upload_files
  WHERE entity_type = 'record' AND entity_id = record_id;
  
  -- Update record with file URLs and mark completed
  UPDATE records
  SET 
    upload_status = 'completed',
    record_url = (
      SELECT file_path FROM upload_files 
      WHERE entity_type = 'record' 
      AND entity_id = record_id 
      AND file_type = 'processed_recording'
      LIMIT 1
    ),
    raw_url = (
      SELECT file_path FROM upload_files 
      WHERE entity_type = 'record' 
      AND entity_id = record_id 
      AND file_type = 'raw_recording'
      LIMIT 1
    )
  WHERE id = record_id;
  
  RETURN json_build_object('success', true, 'files', file_data);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 4️⃣ Failure & Recovery

### A. Handling Interrupted Uploads

**Scenario:** User closes browser mid-upload

**Recovery:**
1. Client detects abandoned uploads on next session
2. Query for records with `upload_status = 'uploading'` older than threshold
3. Offer user options:
   - Resume upload (continue from last file)
   - Retry upload (start over)
   - Delete draft

```sql
-- Find abandoned uploads (older than 1 hour in uploading state)
SELECT r.id, r.upload_status, r.created_at,
  (SELECT COUNT(*) FROM upload_files WHERE entity_type = 'record' AND entity_id = r.id AND upload_status = 'completed') as completed_files,
  (SELECT COUNT(*) FROM upload_files WHERE entity_type = 'record' AND entity_id = r.id) as total_files
FROM records r
WHERE r.upload_status = 'uploading'
  AND r.created_at < now() - INTERVAL '1 hour';
```

### B. Upload Retry Logic

```typescript
async function retryFailedUpload(recordId: string) {
  // Reset status to uploading
  await supabase
    .from('records')
    .update({ 
      upload_status: 'uploading',
      upload_retry_count: supabase.sql`upload_retry_count + 1`
    })
    .eq('id', recordId);
  
  // Get failed files
  const { data: failedFiles } = await supabase
    .from('upload_files')
    .select('*')
    .eq('entity_id', recordId)
    .eq('upload_status', 'failed');
  
  // Retry each failed file
  for (const file of failedFiles) {
    await uploadFileWithRetry(file);
  }
}
```

### C. Cleanup Strategy

**Background job (run daily via pg_cron or Supabase Edge Function):**

```sql
-- Delete orphaned upload_files entries (no parent entity)
DELETE FROM upload_files
WHERE entity_type = 'record'
  AND NOT EXISTS (SELECT 1 FROM records WHERE id = upload_files.entity_id);

-- Mark old drafts as failed (older than 7 days)
UPDATE records
SET upload_status = 'failed',
    upload_error = 'Upload abandoned - exceeded 7 day threshold'
WHERE upload_status = 'draft'
  AND created_at < now() - INTERVAL '7 days';

-- Delete storage files for failed records older than 30 days
-- (implement via Edge Function with storage.from().remove())
```

### D. Error Tracking

```sql
-- Update upload_files with error info
UPDATE upload_files
SET 
  upload_status = 'failed',
  metadata = metadata || jsonb_build_object(
    'error', 'Upload timeout',
    'error_time', now(),
    'retry_count', COALESCE((metadata->>'retry_count')::int, 0) + 1
  )
WHERE id = $1;

-- Update parent record
UPDATE records
SET 
  upload_status = 'failed',
  upload_error = 'One or more file uploads failed'
WHERE id = $2;
```

---

## 5️⃣ Client-Side Integration Guide

### 🎯 Overview for Client Agent

The database provides these **guarantees**:
- Records cannot be marked `completed` without required files
- Status transitions are validated (no invalid state changes)
- Completed records are immutable
- File associations are tracked and verified

The client **must**:
- Create metadata row before uploading files
- Update status to `uploading` when starting uploads
- Call finalization RPC before assuming completion
- Handle retries gracefully
- Never mark records complete directly

### 📝 Client Responsibilities

#### 1. Create Metadata First

```typescript
// ✅ CORRECT: Create DB record first
const { data: record } = await supabase
  .from('records')
  .insert({
    project_id,
    option_id,
    scenario_id,
    device_type,
    upload_status: 'draft' // Always start as draft
  })
  .select()
  .single();

// ❌ WRONG: Upload files before creating record
// This creates orphaned files and breaks associations
```

#### 2. Prepare Upload Entries

```typescript
// Create upload_files entries to track each file
const filesToUpload = [
  {
    entity_type: 'record',
    entity_id: record.id,
    file_type: 'processed_recording',
    file_path: `records/${record.id}/processed_${Date.now()}.glb`,
    is_required: true
  },
  {
    entity_type: 'record',
    entity_id: record.id,
    file_type: 'raw_recording',
    file_path: `records/${record.id}/raw_${Date.now()}.json`,
    is_required: false // Optional file
  }
];

const { data: uploadEntries } = await supabase
  .from('upload_files')
  .insert(filesToUpload)
  .select();
```

#### 3. Transition to Uploading

```typescript
// Mark as uploading BEFORE starting uploads
await supabase
  .from('records')
  .update({ upload_status: 'uploading' })
  .eq('id', record.id);
```

#### 4. Upload Files

```typescript
// Upload each file and track progress
for (const entry of uploadEntries) {
  try {
    // Get signed upload URL
    const { data: signedUrl } = await supabase.storage
      .from('recordings')
      .createSignedUploadUrl(entry.file_path);
    
    // Upload file
    const response = await fetch(signedUrl, {
      method: 'PUT',
      body: files[entry.file_type],
      headers: { 'Content-Type': files[entry.file_type].type }
    });
    
    if (!response.ok) throw new Error('Upload failed');
    
    // Mark file as completed
    await supabase
      .from('upload_files')
      .update({
        upload_status: 'completed',
        uploaded_at: new Date().toISOString(),
        file_size: files[entry.file_type].size,
        verified_at: new Date().toISOString()
      })
      .eq('id', entry.id);
      
  } catch (error) {
    // Mark file as failed
    await supabase
      .from('upload_files')
      .update({
        upload_status: 'failed',
        metadata: { error: error.message }
      })
      .eq('id', entry.id);
    
    throw error;
  }
}
```

#### 5. Finalize Record

```typescript
// ✅ CORRECT: Call finalization RPC
const { data, error } = await supabase.rpc('finalize_record', {
  record_id: record.id
});

if (error) {
  console.error('Finalization failed:', error);
  // Handle error - record stays in 'uploading' state
} else {
  console.log('Record completed:', data);
  // Record is now in 'completed' state
}

// ❌ WRONG: Manually update status
await supabase
  .from('records')
  .update({ upload_status: 'completed' })
  .eq('id', record.id);
// This will FAIL due to validation constraints
```

#### 6. Error Handling

```typescript
try {
  // Upload process
} catch (error) {
  // Mark record as failed
  await supabase
    .from('records')
    .update({
      upload_status: 'failed',
      upload_error: error.message,
      upload_retry_count: record.upload_retry_count + 1
    })
    .eq('id', record.id);
  
  // Show retry option to user
  showRetryDialog(record.id);
}
```

### 🚫 What Client Must NEVER Do

1. **Skip metadata creation**
   - Always create DB row before files
   
2. **Manually mark as completed**
   - Use `finalize_record()` RPC only
   
3. **Assume upload success**
   - Always verify via DB status
   
4. **Upload without status update**
   - Change to `uploading` before starting
   
5. **Ignore failed states**
   - Provide retry mechanisms

### ✅ Complete Flow Example

```typescript
async function uploadRecording(projectId, optionId, scenarioId, files) {
  let recordId;
  
  try {
    // 1. Create metadata
    const { data: record } = await supabase
      .from('records')
      .insert({
        project_id: projectId,
        option_id: optionId,
        scenario_id: scenarioId,
        device_type: 'pc',
        upload_status: 'draft'
      })
      .select()
      .single();
    
    recordId = record.id;
    
    // 2. Prepare upload entries
    const { data: uploadEntries } = await supabase
      .from('upload_files')
      .insert([
        {
          entity_type: 'record',
          entity_id: recordId,
          file_type: 'processed_recording',
          file_path: `records/${recordId}/processed_${Date.now()}.glb`,
          is_required: true
        },
        {
          entity_type: 'record',
          entity_id: recordId,
          file_type: 'raw_recording',
          file_path: `records/${recordId}/raw_${Date.now()}.json`,
          is_required: false
        }
      ])
      .select();
    
    // 3. Start uploading
    await supabase
      .from('records')
      .update({ upload_status: 'uploading' })
      .eq('id', recordId);
    
    // 4. Upload files with progress tracking
    for (const entry of uploadEntries) {
      const file = files[entry.file_type];
      if (!file) continue;
      
      const { data: uploadUrl } = await supabase.storage
        .from('recordings')
        .createSignedUploadUrl(entry.file_path);
      
      await fetch(uploadUrl.signedUrl, {
        method: 'PUT',
        body: file,
        headers: { 'Content-Type': file.type }
      });
      
      await supabase
        .from('upload_files')
        .update({
          upload_status: 'completed',
          uploaded_at: new Date().toISOString(),
          file_size: file.size
        })
        .eq('id', entry.id);
    }
    
    // 5. Finalize
    const { data: result } = await supabase.rpc('finalize_record', {
      record_id: recordId
    });
    
    return { success: true, record: result };
    
  } catch (error) {
    // Mark as failed if record was created
    if (recordId) {
      await supabase
        .from('records')
        .update({
          upload_status: 'failed',
          upload_error: error.message
        })
        .eq('id', recordId);
    }
    
    return { success: false, error: error.message };
  }
}
```

---

## 6️⃣ Migration Path

### A. Migration Order

1. Create new enum type
2. Add new columns to existing tables
3. Create upload_files table
4. Create validation functions
5. Create triggers
6. Create finalization RPC
7. Update storage policies
8. Backfill existing data

### B. Backfill Strategy

```sql
-- Backfill existing records as 'completed' if they have URLs
UPDATE records
SET upload_status = 'completed'
WHERE record_url IS NOT NULL;

-- Mark records without URLs as 'failed'
UPDATE records
SET upload_status = 'failed',
    upload_error = 'Legacy record without files'
WHERE record_url IS NULL;

-- Similar for project_options
UPDATE project_options
SET upload_status = CASE
  WHEN model_url IS NOT NULL THEN 'completed'::upload_status
  ELSE 'draft'::upload_status
END;
```

---

## 7️⃣ Testing Checklist

### Unit Tests (Database Level)

- [ ] Status transitions validate correctly
- [ ] Cannot mark completed without files
- [ ] Completed state is immutable
- [ ] Foreign key cascades work
- [ ] Validation functions throw appropriate errors

### Integration Tests (API Level)

- [ ] Create → Upload → Finalize flow works
- [ ] Partial uploads don't corrupt data
- [ ] Retries work after failures
- [ ] Abandoned uploads are recoverable
- [ ] Storage policies enforce correct access

### E2E Tests (Client Level)

- [ ] Happy path: full upload succeeds
- [ ] Network interruption: can resume
- [ ] File validation: rejects invalid files
- [ ] Progress tracking: accurate percentages
- [ ] Error messages: clear and actionable

---

## 8️⃣ Monitoring & Observability

### Metrics to Track

1. **Upload Success Rate**
   ```sql
   SELECT 
     COUNT(*) FILTER (WHERE upload_status = 'completed') * 100.0 / COUNT(*) as success_rate
   FROM records
   WHERE created_at > now() - INTERVAL '24 hours';
   ```

2. **Average Upload Time**
   ```sql
   SELECT 
     AVG(EXTRACT(EPOCH FROM (updated_at - created_at))) as avg_seconds
   FROM records
   WHERE upload_status = 'completed'
     AND created_at > now() - INTERVAL '24 hours';
   ```

3. **Failed Upload Reasons**
   ```sql
   SELECT upload_error, COUNT(*)
   FROM records
   WHERE upload_status = 'failed'
     AND created_at > now() - INTERVAL '7 days'
   GROUP BY upload_error
   ORDER BY COUNT(*) DESC;
   ```

4. **Abandoned Uploads**
   ```sql
   SELECT COUNT(*)
   FROM records
   WHERE upload_status = 'uploading'
     AND created_at < now() - INTERVAL '1 hour';
   ```

---

## 📚 Summary

### Database Guarantees

✅ No completed records without validated files  
✅ Status transitions are type-safe and validated  
✅ File associations are tracked and enforced  
✅ Completed states are immutable  
✅ Failed uploads are retryable  

### Client Contracts

✅ Must create metadata before uploading  
✅ Must use finalization RPC  
✅ Must handle failures gracefully  
✅ Must track upload progress  
✅ Must provide retry mechanisms  

### Benefits

🎯 **Data Safety** - Invalid states are impossible  
🎯 **UX** - Clear progress and error feedback  
🎯 **Recovery** - Graceful handling of failures  
🎯 **Maintainability** - Clear contracts and guarantees  
🎯 **Scalability** - Supports async, parallel uploads  

---

**Next Steps:**
1. Review and approve this design
2. Create migration SQL file
3. Implement finalization RPC
4. Update client-side code
5. Test thoroughly before deployment
