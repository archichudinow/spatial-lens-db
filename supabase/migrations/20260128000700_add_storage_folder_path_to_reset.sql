-- =============================================================================
-- Migration: Return storage folder path for complete cleanup
-- =============================================================================
-- Purpose: Return the storage folder path so frontend can delete ALL files
--          in the folder, not just tracked upload_files records
-- Created: 2026-01-28
-- =============================================================================

-- =============================================================================
-- 1. UPDATE: reset_option_for_reupload to return folder path
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
  v_folder_path TEXT;
  v_project_id UUID;
  v_project_name TEXT;
  v_result JSON;
BEGIN
  -- Get current status and project info
  SELECT o.upload_status, o.project_id, p.name
  INTO v_old_status, v_project_id, v_project_name
  FROM project_options o
  INNER JOIN projects p ON o.project_id = p.id
  WHERE o.id = p_option_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Option not found with id: %', p_option_id;
  END IF;

  IF v_old_status != 'completed' THEN
    RAISE EXCEPTION 'Can only reset completed uploads. Current status: %', v_old_status;
  END IF;

  -- Calculate storage folder path
  -- Format: {sanitized_project_name}_{project_id}/options/{option_id}/
  v_folder_path := regexp_replace(lower(v_project_name), '[^a-z0-9]+', '_', 'g') 
    || '_' || v_project_id 
    || '/options/' || p_option_id || '/';

  -- Get storage paths that need to be deleted (from tracked files)
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
    'storage_folder_path', v_folder_path,
    'storage_paths_to_delete', v_storage_paths,
    'message', 'Option reset successfully. Delete ALL files in storage_folder_path to ensure complete cleanup.'
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
'Resets a completed option back to draft status. Returns storage_folder_path for deleting ALL files in folder (not just tracked ones).';

-- =============================================================================
-- 2. UPDATE: reset_record_for_reupload to return folder path
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
  v_folder_path TEXT;
  v_project_id UUID;
  v_project_name TEXT;
  v_option_id UUID;
  v_scenario_id UUID;
  v_result JSON;
BEGIN
  -- Get current status and project/option/scenario info
  SELECT r.upload_status, r.project_id, r.option_id, r.scenario_id, p.name
  INTO v_old_status, v_project_id, v_option_id, v_scenario_id, v_project_name
  FROM records r
  INNER JOIN projects p ON r.project_id = p.id
  WHERE r.id = p_record_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Record not found with id: %', p_record_id;
  END IF;

  IF v_old_status != 'completed' THEN
    RAISE EXCEPTION 'Can only reset completed uploads. Current status: %', v_old_status;
  END IF;

  -- Calculate storage folder paths for records
  -- Format: {project}/records/records_glb/{option_id}/{scenario_id}/
  -- and:    {project}/records/records_csv/{option_id}/{scenario_id}/
  v_folder_path := regexp_replace(lower(v_project_name), '[^a-z0-9]+', '_', 'g') 
    || '_' || v_project_id 
    || '/records/';

  -- Get storage paths that need to be deleted (from tracked files)
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
    raw_url = NULL,
    upload_status = 'draft',
    updated_at = NOW()
  WHERE id = p_record_id;

  v_result := json_build_object(
    'success', true,
    'record_id', p_record_id,
    'previous_status', v_old_status,
    'new_status', 'draft',
    'deleted_files_count', v_deleted_files_count,
    'storage_folder_path', v_folder_path || 'records_glb/' || v_option_id || '/' || v_scenario_id || '/',
    'storage_folder_path_csv', v_folder_path || 'records_csv/' || v_option_id || '/' || v_scenario_id || '/',
    'storage_paths_to_delete', v_storage_paths,
    'message', 'Record reset successfully. Delete ALL files in storage folder paths to ensure complete cleanup.'
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
'Resets a completed record back to draft status. Returns storage_folder_paths for deleting ALL files in folders (not just tracked ones).';
