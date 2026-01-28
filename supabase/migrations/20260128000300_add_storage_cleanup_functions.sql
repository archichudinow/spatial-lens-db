-- =============================================================================
-- Migration: Add Storage Cleanup Functions
-- =============================================================================
-- Purpose: Clean up orphaned storage files when deleting/replacing uploads
-- Created: 2026-01-28
-- =============================================================================

-- =============================================================================
-- 1. HELPER FUNCTION: Delete files from storage bucket
-- =============================================================================
-- Note: This returns paths that need to be deleted. 
-- The actual deletion must be done by Edge Functions with service_role permissions

CREATE OR REPLACE FUNCTION get_storage_paths_for_deletion(
  p_entity_type TEXT,
  p_entity_id UUID
)
RETURNS TABLE(storage_path TEXT, file_type TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    uf.file_path,
    uf.file_type
  FROM upload_files uf
  WHERE uf.entity_type = p_entity_type 
    AND uf.entity_id = p_entity_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_storage_paths_for_deletion(TEXT, UUID) IS
'Returns storage paths that should be deleted for a given entity. Call this before deleting upload_files records.';

-- =============================================================================
-- 2. HELPER FUNCTION: Get all storage paths for a project
-- =============================================================================

CREATE OR REPLACE FUNCTION get_project_storage_paths(p_project_id UUID)
RETURNS TABLE(storage_path TEXT, entity_type TEXT, entity_id UUID) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    uf.file_path,
    uf.entity_type,
    uf.entity_id
  FROM upload_files uf
  WHERE uf.entity_id IN (
    -- Get all options for this project
    SELECT id FROM project_options WHERE project_id = p_project_id
    UNION
    -- Get all records for this project
    SELECT id FROM records WHERE project_id = p_project_id
    UNION
    -- Get the project itself
    SELECT p_project_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_project_storage_paths(UUID) IS
'Returns all storage paths associated with a project (options, records, etc). Use for bulk cleanup.';

-- =============================================================================
-- 3. UPDATE reset_option_for_reupload to return storage paths
-- =============================================================================

CREATE OR REPLACE FUNCTION reset_option_for_reupload(p_option_id UUID)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_status TEXT;
  v_deleted_files_count INT;
  v_project_id UUID;
  v_storage_paths JSON;
  v_result JSON;
BEGIN
  -- Get current status and check permissions
  SELECT o.upload_status, o.project_id INTO v_old_status, v_project_id
  FROM project_options o
  INNER JOIN projects p ON o.project_id = p.id
  WHERE o.id = p_option_id
    AND p.user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Option not found or you do not have permission to modify it';
  END IF;

  IF v_old_status != 'completed' THEN
    RAISE EXCEPTION 'Can only reset completed uploads. Current status: %', v_old_status;
  END IF;

  -- Get storage paths that need to be deleted
  SELECT json_agg(json_build_object('path', file_path, 'type', file_type))
  INTO v_storage_paths
  FROM upload_files
  WHERE entity_type = 'option' AND entity_id = p_option_id;

  -- Delete upload_files entries
  WITH deleted AS (
    DELETE FROM upload_files
    WHERE entity_type = 'option' AND entity_id = p_option_id
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_files_count FROM deleted;

  -- Update option
  UPDATE project_options
  SET 
    model_url = NULL,
    upload_status = 'draft',
    updated_at = NOW()
  WHERE id = p_option_id;

  v_result := json_build_object(
    'success', true,
    'option_id', p_option_id,
    'previous_status', v_old_status,
    'new_status', 'draft',
    'deleted_files_count', v_deleted_files_count,
    'storage_paths_to_delete', v_storage_paths,
    'message', 'Option reset successfully. Delete storage files using the paths provided.'
  );

  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM,
      'option_id', p_option_id
    );
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 4. UPDATE reset_record_for_reupload to return storage paths
-- =============================================================================

CREATE OR REPLACE FUNCTION reset_record_for_reupload(p_record_id UUID)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_status TEXT;
  v_deleted_files_count INT;
  v_project_id UUID;
  v_storage_paths JSON;
  v_result JSON;
BEGIN
  SELECT r.upload_status, r.project_id INTO v_old_status, v_project_id
  FROM records r
  INNER JOIN projects p ON r.project_id = p.id
  WHERE r.id = p_record_id
    AND p.user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Record not found or you do not have permission to modify it';
  END IF;

  IF v_old_status != 'completed' THEN
    RAISE EXCEPTION 'Can only reset completed uploads. Current status: %', v_old_status;
  END IF;

  -- Get storage paths that need to be deleted
  SELECT json_agg(json_build_object('path', file_path, 'type', file_type))
  INTO v_storage_paths
  FROM upload_files
  WHERE entity_type = 'record' AND entity_id = p_record_id;

  -- Delete upload_files entries
  WITH deleted AS (
    DELETE FROM upload_files
    WHERE entity_type = 'record' AND entity_id = p_record_id
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_files_count FROM deleted;

  UPDATE records
  SET 
    record_url = NULL,
    upload_status = 'draft',
    updated_at = NOW()
  WHERE id = p_record_id;

  v_result := json_build_object(
    'success', true,
    'record_id', p_record_id,
    'previous_status', v_old_status,
    'new_status', 'draft',
    'deleted_files_count', v_deleted_files_count,
    'storage_paths_to_delete', v_storage_paths,
    'message', 'Record reset successfully. Delete storage files using the paths provided.'
  );

  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM,
      'record_id', p_record_id
    );
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 5. NEW FUNCTION: Get orphaned storage paths for cleanup
-- =============================================================================

CREATE OR REPLACE FUNCTION find_orphaned_storage_files()
RETURNS JSON
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_orphaned_paths JSON;
BEGIN
  -- Find upload_files where the parent entity no longer exists
  SELECT json_agg(json_build_object(
    'path', uf.file_path,
    'entity_type', uf.entity_type,
    'entity_id', uf.entity_id,
    'file_type', uf.file_type,
    'created_at', uf.created_at
  ))
  INTO v_orphaned_paths
  FROM upload_files uf
  WHERE 
    (uf.entity_type = 'option' AND NOT EXISTS (SELECT 1 FROM project_options WHERE id = uf.entity_id))
    OR
    (uf.entity_type = 'record' AND NOT EXISTS (SELECT 1 FROM records WHERE id = uf.entity_id))
    OR
    (uf.entity_type = 'project' AND NOT EXISTS (SELECT 1 FROM projects WHERE id = uf.entity_id));

  RETURN json_build_object(
    'success', true,
    'orphaned_files', COALESCE(v_orphaned_paths, '[]'::json),
    'message', 'Found orphaned files. Delete from storage and clean up database records.'
  );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION find_orphaned_storage_files() IS
'Finds upload_files records where the parent entity (option/record/project) no longer exists. Returns paths for cleanup.';

-- =============================================================================
-- 6. NEW FUNCTION: Clean up orphaned upload_files records
-- =============================================================================

CREATE OR REPLACE FUNCTION cleanup_orphaned_upload_files()
RETURNS JSON
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted_count INT;
  v_deleted_paths JSON;
BEGIN
  -- Get paths before deleting
  SELECT json_agg(json_build_object('path', file_path, 'type', file_type))
  INTO v_deleted_paths
  FROM upload_files uf
  WHERE 
    (uf.entity_type = 'option' AND NOT EXISTS (SELECT 1 FROM project_options WHERE id = uf.entity_id))
    OR
    (uf.entity_type = 'record' AND NOT EXISTS (SELECT 1 FROM records WHERE id = uf.entity_id))
    OR
    (uf.entity_type = 'project' AND NOT EXISTS (SELECT 1 FROM projects WHERE id = uf.entity_id));

  -- Delete orphaned records
  WITH deleted AS (
    DELETE FROM upload_files uf
    WHERE 
      (uf.entity_type = 'option' AND NOT EXISTS (SELECT 1 FROM project_options WHERE id = uf.entity_id))
      OR
      (uf.entity_type = 'record' AND NOT EXISTS (SELECT 1 FROM records WHERE id = uf.entity_id))
      OR
      (uf.entity_type = 'project' AND NOT EXISTS (SELECT 1 FROM projects WHERE id = uf.entity_id))
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_count FROM deleted;

  RETURN json_build_object(
    'success', true,
    'deleted_records', v_deleted_count,
    'storage_paths_to_delete', COALESCE(v_deleted_paths, '[]'::json),
    'message', format('Cleaned up %s orphaned upload_files records. Delete storage files using paths provided.', v_deleted_count)
  );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_orphaned_upload_files() IS
'Deletes upload_files records where parent entity no longer exists. Returns storage paths for manual deletion.';

-- =============================================================================
-- 7. GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION get_storage_paths_for_deletion(TEXT, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_project_storage_paths(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION find_orphaned_storage_files() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION cleanup_orphaned_upload_files() TO authenticated, service_role;
