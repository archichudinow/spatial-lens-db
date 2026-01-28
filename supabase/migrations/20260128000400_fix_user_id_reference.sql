-- =============================================================================
-- Migration: Fix user_id Reference in Reset Functions
-- =============================================================================
-- Purpose: Remove non-existent user_id checks since projects table has no
--          ownership column. RLS policies allow any authenticated user to
--          modify any project.
-- Created: 2026-01-28
-- =============================================================================

-- =============================================================================
-- 1. FIX: Reset Option for Re-upload - Remove user_id check
-- =============================================================================

CREATE OR REPLACE FUNCTION reset_option_for_reupload(p_option_id UUID)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_status TEXT;
  v_deleted_files_count INT;
  v_storage_paths JSON;
  v_result JSON;
BEGIN
  -- Get current status (removed user permission check - no user_id column exists)
  SELECT o.upload_status INTO v_old_status
  FROM project_options o
  WHERE o.id = p_option_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Option not found with id: %', p_option_id;
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

COMMENT ON FUNCTION reset_option_for_reupload(UUID) IS 
'Resets a completed option back to draft status for re-uploading. Returns storage paths for deletion.';

-- =============================================================================
-- 2. FIX: Reset Record for Re-upload - Remove user_id check
-- =============================================================================

CREATE OR REPLACE FUNCTION reset_record_for_reupload(p_record_id UUID)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_status TEXT;
  v_deleted_files_count INT;
  v_storage_paths JSON;
  v_result JSON;
BEGIN
  -- Get current status (removed user permission check - no user_id column exists)
  SELECT r.upload_status INTO v_old_status
  FROM records r
  WHERE r.id = p_record_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Record not found with id: %', p_record_id;
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

COMMENT ON FUNCTION reset_record_for_reupload(UUID) IS 
'Resets a completed record back to draft status for re-uploading. Returns storage paths for deletion.';
