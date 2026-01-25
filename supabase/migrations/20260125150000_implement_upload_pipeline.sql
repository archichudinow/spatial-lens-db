-- Migration: Implement Upload Pipeline
-- Description: Add upload status tracking, file management, and validation
-- Date: 2026-01-25
-- Related: UPLOAD_PIPELINE_DESIGN.md

-- =============================================================================
-- 1. CREATE UPLOAD STATUS ENUM
-- =============================================================================

CREATE TYPE upload_status AS ENUM (
  'draft',      -- Metadata created, no uploads started
  'uploading',  -- Files are being uploaded
  'completed',  -- All required files validated and linked
  'failed'      -- Upload or processing failed, recoverable
);

COMMENT ON TYPE upload_status IS 'Tracks the lifecycle state of file uploads for entities';

-- =============================================================================
-- 2. ADD UPLOAD STATUS TO EXISTING TABLES
-- =============================================================================

-- Add to projects table (for context models, heatmaps)
ALTER TABLE projects 
  ADD COLUMN upload_status upload_status DEFAULT 'draft',
  ADD COLUMN required_files JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN uploaded_files JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN projects.upload_status IS 'Upload status for project-level files (context models, heatmaps)';
COMMENT ON COLUMN projects.required_files IS 'Array of required file types for this project';
COMMENT ON COLUMN projects.uploaded_files IS 'Array of successfully uploaded file metadata';

-- Add to project_options table (for model files)
ALTER TABLE project_options
  ADD COLUMN upload_status upload_status DEFAULT 'draft',
  ADD COLUMN model_file_size BIGINT,
  ADD COLUMN model_uploaded_at TIMESTAMP WITH TIME ZONE;

COMMENT ON COLUMN project_options.upload_status IS 'Upload status for option model file';
COMMENT ON COLUMN project_options.model_file_size IS 'Size in bytes of uploaded model file';
COMMENT ON COLUMN project_options.model_uploaded_at IS 'Timestamp when model was successfully uploaded';

-- Add to records table (for recordings)
ALTER TABLE records
  ADD COLUMN upload_status upload_status DEFAULT 'draft',
  ADD COLUMN raw_file_size BIGINT,
  ADD COLUMN record_file_size BIGINT,
  ADD COLUMN raw_uploaded_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN record_uploaded_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN upload_error TEXT,
  ADD COLUMN upload_retry_count INTEGER DEFAULT 0;

COMMENT ON COLUMN records.upload_status IS 'Upload status for recording files';
COMMENT ON COLUMN records.raw_file_size IS 'Size in bytes of raw recording file';
COMMENT ON COLUMN records.record_file_size IS 'Size in bytes of processed recording file';
COMMENT ON COLUMN records.upload_error IS 'Error message if upload failed';
COMMENT ON COLUMN records.upload_retry_count IS 'Number of times upload has been retried';

-- Make URLs nullable during upload phase (they'll be populated on completion)
ALTER TABLE records ALTER COLUMN raw_url DROP NOT NULL;
ALTER TABLE records ALTER COLUMN record_url DROP NOT NULL;

-- =============================================================================
-- 3. CREATE UPLOAD FILES TABLE
-- =============================================================================

CREATE TABLE upload_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Parent entity reference (polymorphic)
  entity_type TEXT NOT NULL CHECK (entity_type IN ('project', 'option', 'record')),
  entity_id UUID NOT NULL,
  
  -- File metadata
  file_type TEXT NOT NULL CHECK (file_type IN ('model', 'raw_recording', 'processed_recording', 'context_model', 'heatmap')),
  file_path TEXT NOT NULL, -- Storage path (bucket + path)
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
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE,
  
  -- Ensure file paths are unique
  CONSTRAINT upload_files_file_path_unique UNIQUE(file_path)
);

ALTER TABLE upload_files OWNER TO postgres;

-- Indexes for performance
CREATE INDEX idx_upload_files_entity ON upload_files(entity_type, entity_id);
CREATE INDEX idx_upload_files_status ON upload_files(upload_status);
CREATE INDEX idx_upload_files_type ON upload_files(file_type);
CREATE INDEX idx_upload_files_created_at ON upload_files(created_at DESC);

COMMENT ON TABLE upload_files IS 'Tracks individual file uploads and their association with parent entities';
COMMENT ON COLUMN upload_files.entity_type IS 'Type of parent entity (project, option, or record)';
COMMENT ON COLUMN upload_files.entity_id IS 'UUID of parent entity';
COMMENT ON COLUMN upload_files.file_type IS 'Type of file being uploaded';
COMMENT ON COLUMN upload_files.file_path IS 'Full storage path including bucket';
COMMENT ON COLUMN upload_files.is_required IS 'Whether this file is required for entity completion';

-- Add trigger for updated_at
CREATE TRIGGER trigger_update_upload_files_updated_at
  BEFORE UPDATE ON upload_files
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 4. VALIDATION FUNCTION: Prevent invalid status transitions
-- =============================================================================

CREATE OR REPLACE FUNCTION validate_status_transition()
RETURNS TRIGGER AS $$
BEGIN
  -- Only validate if status is actually changing
  IF OLD.upload_status IS NOT NULL AND NEW.upload_status != OLD.upload_status THEN
    
    -- Completed state is immutable - cannot transition away from it
    IF OLD.upload_status = 'completed' THEN
      RAISE EXCEPTION 'Cannot change status from completed to %. Completed records are immutable.', NEW.upload_status;
    END IF;
    
    -- From draft: can only go to uploading or failed
    IF OLD.upload_status = 'draft' AND NEW.upload_status NOT IN ('uploading', 'failed') THEN
      RAISE EXCEPTION 'Invalid transition from draft to %. Must transition to uploading or failed.', NEW.upload_status;
    END IF;
    
    -- From uploading: can only go to completed or failed
    IF OLD.upload_status = 'uploading' AND NEW.upload_status NOT IN ('completed', 'failed') THEN
      RAISE EXCEPTION 'Invalid transition from uploading to %. Must transition to completed or failed.', NEW.upload_status;
    END IF;
    
    -- From failed: can go to uploading (retry) or draft (reset)
    IF OLD.upload_status = 'failed' AND NEW.upload_status NOT IN ('uploading', 'draft') THEN
      RAISE EXCEPTION 'Invalid transition from failed to %. Can only retry (uploading) or reset (draft).', NEW.upload_status;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_status_transition() IS 'Validates upload status transitions to prevent invalid state changes';

-- =============================================================================
-- 5. VALIDATION FUNCTION: Ensure files exist before marking completed
-- =============================================================================

CREATE OR REPLACE FUNCTION validate_entity_completion()
RETURNS TRIGGER AS $$
DECLARE
  required_count INTEGER;
  completed_count INTEGER;
BEGIN
  -- Only validate when transitioning TO completed
  IF NEW.upload_status = 'completed' AND (OLD.upload_status IS NULL OR OLD.upload_status != 'completed') THEN
    
    -- Validation for RECORDS table
    IF TG_TABLE_NAME = 'records' THEN
      -- Ensure record_url is populated
      IF NEW.record_url IS NULL OR NEW.record_url = '' THEN
        RAISE EXCEPTION 'Cannot mark record as completed: record_url is required';
      END IF;
      
      -- Check upload_files table for required files
      SELECT 
        COUNT(*) FILTER (WHERE is_required = true),
        COUNT(*) FILTER (WHERE is_required = true AND upload_status = 'completed')
      INTO required_count, completed_count
      FROM upload_files
      WHERE entity_type = 'record' AND entity_id = NEW.id;
      
      -- If there are tracked files, ensure all required ones are completed
      IF required_count > 0 AND completed_count < required_count THEN
        RAISE EXCEPTION 'Cannot mark record as completed: only % of % required files are uploaded',
          completed_count, required_count;
      END IF;
    END IF;
    
    -- Validation for PROJECT_OPTIONS table
    IF TG_TABLE_NAME = 'project_options' THEN
      -- If model_url is set, ensure file metadata exists
      IF NEW.model_url IS NOT NULL AND NEW.model_file_size IS NULL THEN
        RAISE EXCEPTION 'Cannot mark option as completed: model file size not recorded';
      END IF;
    END IF;
    
    -- Validation for PROJECTS table
    IF TG_TABLE_NAME = 'projects' THEN
      -- Check upload_files table for required files
      SELECT 
        COUNT(*) FILTER (WHERE is_required = true),
        COUNT(*) FILTER (WHERE is_required = true AND upload_status = 'completed')
      INTO required_count, completed_count
      FROM upload_files
      WHERE entity_type = 'project' AND entity_id = NEW.id;
      
      -- If there are tracked files, ensure all required ones are completed
      IF required_count > 0 AND completed_count < required_count THEN
        RAISE EXCEPTION 'Cannot mark project as completed: only % of % required files are uploaded',
          completed_count, required_count;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_entity_completion() IS 'Validates that all required files exist before allowing entity to be marked as completed';

-- =============================================================================
-- 6. ATTACH VALIDATION TRIGGERS
-- =============================================================================

-- Trigger for records
CREATE TRIGGER validate_records_status_transition
  BEFORE UPDATE ON records
  FOR EACH ROW
  EXECUTE FUNCTION validate_status_transition();

CREATE TRIGGER validate_records_completion
  BEFORE UPDATE ON records
  FOR EACH ROW
  EXECUTE FUNCTION validate_entity_completion();

-- Trigger for project_options
CREATE TRIGGER validate_options_status_transition
  BEFORE UPDATE ON project_options
  FOR EACH ROW
  EXECUTE FUNCTION validate_status_transition();

CREATE TRIGGER validate_options_completion
  BEFORE UPDATE ON project_options
  FOR EACH ROW
  EXECUTE FUNCTION validate_entity_completion();

-- Trigger for projects
CREATE TRIGGER validate_projects_status_transition
  BEFORE UPDATE ON projects
  FOR EACH ROW
  EXECUTE FUNCTION validate_status_transition();

CREATE TRIGGER validate_projects_completion
  BEFORE UPDATE ON projects
  FOR EACH ROW
  EXECUTE FUNCTION validate_entity_completion();

-- =============================================================================
-- 7. RPC FUNCTION: Finalize record upload
-- =============================================================================

CREATE OR REPLACE FUNCTION finalize_record(record_id UUID)
RETURNS JSON AS $$
DECLARE
  required_count INTEGER;
  completed_count INTEGER;
  file_data JSON;
  record_data records%ROWTYPE;
BEGIN
  -- Get current record data
  SELECT * INTO record_data FROM records WHERE id = record_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Record not found: %', record_id;
  END IF;
  
  -- Check all required files are completed
  SELECT 
    COUNT(*) FILTER (WHERE is_required = true),
    COUNT(*) FILTER (WHERE is_required = true AND upload_status = 'completed')
  INTO required_count, completed_count
  FROM upload_files
  WHERE entity_type = 'record' AND entity_id = record_id;
  
  IF required_count > completed_count THEN
    RAISE EXCEPTION 'Cannot finalize record: % of % required files not completed', 
      (required_count - completed_count), required_count;
  END IF;
  
  -- Get file URLs and metadata
  SELECT json_agg(json_build_object(
    'type', file_type,
    'url', file_path,
    'size', file_size,
    'mime_type', mime_type,
    'uploaded_at', uploaded_at
  )) INTO file_data
  FROM upload_files
  WHERE entity_type = 'record' AND entity_id = record_id
    AND upload_status = 'completed';
  
  -- Update record with file URLs and mark completed
  UPDATE records
  SET 
    upload_status = 'completed',
    record_url = COALESCE(
      (SELECT file_path FROM upload_files 
       WHERE entity_type = 'record' 
       AND entity_id = record_id 
       AND file_type = 'processed_recording'
       AND upload_status = 'completed'
       LIMIT 1),
      record_url -- Keep existing if no upload_file entry
    ),
    raw_url = COALESCE(
      (SELECT file_path FROM upload_files 
       WHERE entity_type = 'record' 
       AND entity_id = record_id 
       AND file_type = 'raw_recording'
       AND upload_status = 'completed'
       LIMIT 1),
      raw_url -- Keep existing if no upload_file entry
    ),
    record_file_size = COALESCE(
      (SELECT file_size FROM upload_files 
       WHERE entity_type = 'record' 
       AND entity_id = record_id 
       AND file_type = 'processed_recording'
       LIMIT 1),
      record_file_size
    ),
    raw_file_size = COALESCE(
      (SELECT file_size FROM upload_files 
       WHERE entity_type = 'record' 
       AND entity_id = record_id 
       AND file_type = 'raw_recording'
       LIMIT 1),
      raw_file_size
    ),
    record_uploaded_at = now()
  WHERE id = record_id;
  
  -- Return success with file data
  RETURN json_build_object(
    'success', true,
    'record_id', record_id,
    'files', file_data,
    'completed_at', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION finalize_record(UUID) IS 'Finalizes a record upload by verifying all files and marking as completed';

-- =============================================================================
-- 8. RPC FUNCTION: Finalize option upload
-- =============================================================================

CREATE OR REPLACE FUNCTION finalize_option(option_id UUID)
RETURNS JSON AS $$
DECLARE
  required_count INTEGER;
  completed_count INTEGER;
  file_data JSON;
  option_data project_options%ROWTYPE;
BEGIN
  -- Get current option data
  SELECT * INTO option_data FROM project_options WHERE id = option_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Option not found: %', option_id;
  END IF;
  
  -- Check all required files are completed
  SELECT 
    COUNT(*) FILTER (WHERE is_required = true),
    COUNT(*) FILTER (WHERE is_required = true AND upload_status = 'completed')
  INTO required_count, completed_count
  FROM upload_files
  WHERE entity_type = 'option' AND entity_id = option_id;
  
  IF required_count > completed_count THEN
    RAISE EXCEPTION 'Cannot finalize option: % of % required files not completed', 
      (required_count - completed_count), required_count;
  END IF;
  
  -- Get file URLs and metadata
  SELECT json_agg(json_build_object(
    'type', file_type,
    'url', file_path,
    'size', file_size,
    'mime_type', mime_type,
    'uploaded_at', uploaded_at
  )) INTO file_data
  FROM upload_files
  WHERE entity_type = 'option' AND entity_id = option_id
    AND upload_status = 'completed';
  
  -- Update option with file URL and mark completed
  UPDATE project_options
  SET 
    upload_status = 'completed',
    model_url = COALESCE(
      (SELECT file_path FROM upload_files 
       WHERE entity_type = 'option' 
       AND entity_id = option_id 
       AND file_type = 'model'
       AND upload_status = 'completed'
       LIMIT 1),
      model_url
    ),
    model_file_size = COALESCE(
      (SELECT file_size FROM upload_files 
       WHERE entity_type = 'option' 
       AND entity_id = option_id 
       AND file_type = 'model'
       LIMIT 1),
      model_file_size
    ),
    model_uploaded_at = now()
  WHERE id = option_id;
  
  -- Return success with file data
  RETURN json_build_object(
    'success', true,
    'option_id', option_id,
    'files', file_data,
    'completed_at', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION finalize_option(UUID) IS 'Finalizes an option upload by verifying all files and marking as completed';

-- =============================================================================
-- 9. CLEANUP FUNCTION: Find abandoned uploads
-- =============================================================================

CREATE OR REPLACE FUNCTION find_abandoned_uploads(threshold_hours INTEGER DEFAULT 1)
RETURNS TABLE(
  entity_type TEXT,
  entity_id UUID,
  upload_status upload_status,
  created_at TIMESTAMP WITH TIME ZONE,
  hours_old NUMERIC,
  completed_files INTEGER,
  total_files INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    'record'::TEXT as entity_type,
    r.id as entity_id,
    r.upload_status,
    r.created_at,
    EXTRACT(EPOCH FROM (now() - r.created_at)) / 3600 as hours_old,
    (SELECT COUNT(*)::INTEGER FROM upload_files 
     WHERE upload_files.entity_type = 'record' 
     AND upload_files.entity_id = r.id 
     AND upload_files.upload_status = 'completed') as completed_files,
    (SELECT COUNT(*)::INTEGER FROM upload_files 
     WHERE upload_files.entity_type = 'record' 
     AND upload_files.entity_id = r.id) as total_files
  FROM records r
  WHERE r.upload_status IN ('draft', 'uploading')
    AND r.created_at < now() - (threshold_hours || ' hours')::INTERVAL
  
  UNION ALL
  
  SELECT 
    'option'::TEXT as entity_type,
    o.id as entity_id,
    o.upload_status,
    o.created_at,
    EXTRACT(EPOCH FROM (now() - o.created_at)) / 3600 as hours_old,
    (SELECT COUNT(*)::INTEGER FROM upload_files 
     WHERE upload_files.entity_type = 'option' 
     AND upload_files.entity_id = o.id 
     AND upload_files.upload_status = 'completed') as completed_files,
    (SELECT COUNT(*)::INTEGER FROM upload_files 
     WHERE upload_files.entity_type = 'option' 
     AND upload_files.entity_id = o.id) as total_files
  FROM project_options o
  WHERE o.upload_status IN ('draft', 'uploading')
    AND o.created_at < now() - (threshold_hours || ' hours')::INTERVAL;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION find_abandoned_uploads(INTEGER) IS 'Finds uploads that have been in draft/uploading state longer than threshold';

-- =============================================================================
-- 10. BACKFILL EXISTING DATA
-- =============================================================================

-- Temporarily disable triggers for backfill to avoid validation during migration
ALTER TABLE records DISABLE TRIGGER validate_records_status_transition;
ALTER TABLE records DISABLE TRIGGER validate_records_completion;
ALTER TABLE project_options DISABLE TRIGGER validate_options_status_transition;
ALTER TABLE project_options DISABLE TRIGGER validate_options_completion;
ALTER TABLE projects DISABLE TRIGGER validate_projects_status_transition;
ALTER TABLE projects DISABLE TRIGGER validate_projects_completion;

-- Backfill records: mark existing records with URLs as completed
UPDATE records
SET upload_status = 'completed',
    record_uploaded_at = created_at
WHERE record_url IS NOT NULL 
  AND record_url != '';

-- Backfill records: mark records without URLs as failed
UPDATE records
SET 
  upload_status = 'failed',
  upload_error = 'Legacy record migrated without files'
WHERE record_url IS NULL OR record_url = '';

-- Backfill project_options: mark options with model URLs as completed
UPDATE project_options
SET upload_status = 'completed',
    model_uploaded_at = created_at
WHERE model_url IS NOT NULL 
  AND model_url != '';

-- Backfill project_options: mark options without models as draft
UPDATE project_options
SET upload_status = 'draft'
WHERE model_url IS NULL OR model_url = '';

-- Backfill projects: mark all as draft (no files typically uploaded at project level yet)
UPDATE projects
SET upload_status = 'draft';

-- Re-enable triggers after backfill
ALTER TABLE records ENABLE TRIGGER validate_records_status_transition;
ALTER TABLE records ENABLE TRIGGER validate_records_completion;
ALTER TABLE project_options ENABLE TRIGGER validate_options_status_transition;
ALTER TABLE project_options ENABLE TRIGGER validate_options_completion;
ALTER TABLE projects ENABLE TRIGGER validate_projects_status_transition;
ALTER TABLE projects ENABLE TRIGGER validate_projects_completion;

-- =============================================================================
-- 11. RLS POLICIES FOR UPLOAD_FILES TABLE
-- =============================================================================

-- Enable RLS
ALTER TABLE upload_files ENABLE ROW LEVEL SECURITY;

-- Public can view upload files for released projects
CREATE POLICY "Public can view upload_files for released projects"
ON upload_files FOR SELECT
USING (
  entity_type = 'record' AND EXISTS (
    SELECT 1 FROM records r
    JOIN projects p ON p.id = r.project_id
    WHERE r.id = upload_files.entity_id
    AND p.status = 'released'
  )
  OR entity_type = 'option' AND EXISTS (
    SELECT 1 FROM project_options o
    JOIN projects p ON p.id = o.project_id
    WHERE o.id = upload_files.entity_id
    AND p.status = 'released'
  )
  OR entity_type = 'project' AND EXISTS (
    SELECT 1 FROM projects p
    WHERE p.id = upload_files.entity_id
    AND p.status = 'released'
  )
);

-- Authenticated users can view all upload files
CREATE POLICY "Authenticated users can view all upload_files"
ON upload_files FOR SELECT
TO authenticated
USING (true);

-- Authenticated users can create upload file entries
CREATE POLICY "Authenticated users can create upload_files"
ON upload_files FOR INSERT
TO authenticated
WITH CHECK (true);

-- Authenticated users can update upload files
CREATE POLICY "Authenticated users can update upload_files"
ON upload_files FOR UPDATE
TO authenticated
USING (true);

-- Authenticated users can delete upload files
CREATE POLICY "Authenticated users can delete upload_files"
ON upload_files FOR DELETE
TO authenticated
USING (true);

-- =============================================================================
-- 12. GRANT PERMISSIONS
-- =============================================================================

-- Grant execute on RPC functions to authenticated users
GRANT EXECUTE ON FUNCTION finalize_record(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION finalize_option(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION find_abandoned_uploads(INTEGER) TO authenticated;

-- Grant execute on RPC functions to anon (if needed for public upload)
GRANT EXECUTE ON FUNCTION finalize_record(UUID) TO anon;

-- =============================================================================
-- END OF MIGRATION
-- =============================================================================
