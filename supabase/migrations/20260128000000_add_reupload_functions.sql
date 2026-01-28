-- =============================================================================
-- Migration: Add RPC Functions for Re-uploading Completed Files
-- =============================================================================
-- Purpose: Allow users to reset completed uploads back to draft status
--          for re-uploading, bypassing the immutability trigger
-- Created: 2026-01-28
-- =============================================================================

-- =============================================================================
-- 1. RPC FUNCTION: Reset Option for Re-upload
-- =============================================================================

CREATE OR REPLACE FUNCTION reset_option_for_reupload(p_option_id UUID)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_status TEXT;
  v_deleted_files_count INT;
  v_result JSON;
BEGIN
  -- Get current status 
  SELECT upload_status INTO v_old_status
  FROM options
  WHERE id = p_option_id;

  -- Check if option exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Option not found with id: %', p_option_id;
  END IF;

  -- Only allow reset if currently completed
  IF v_old_status != 'completed' THEN
    RAISE EXCEPTION 'Can only reset completed uploads. Current status: %', v_old_status;
  END IF;

  -- Delete associated upload_files entries
  WITH deleted AS (
    DELETE FROM upload_files
    WHERE entity_type = 'option' AND entity_id = p_option_id
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_files_count FROM deleted;

  -- Update option: clear model_url and reset status to draft
  -- Using UPDATE directly bypasses the trigger because we're using SECURITY DEFINER
  -- and the trigger only applies to normal user operations
  UPDATE project_options
  SET 
    model_url = NULL,
    upload_status = 'draft',
    updated_at = NOW()
  WHERE id = p_option_id;

  -- Build result
  v_result := json_build_object(
    'success', true,
    'option_id', p_option_id,
    'previous_status', v_old_status,
    'new_status', 'draft',
    'deleted_files_count', v_deleted_files_count,
    'message', 'Option reset successfully for re-upload'
  );

  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    -- Return error details
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM,
      'option_id', p_option_id
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION reset_option_for_reupload(UUID) IS 
'Resets a completed option back to draft status for re-uploading. Deletes associated upload_files and clears model_url. Uses SECURITY DEFINER to bypass immutability trigger.';

-- =============================================================================
-- 2. RPC FUNCTION: Reset Record for Re-upload
-- =============================================================================

CREATE OR REPLACE FUNCTION reset_record_for_reupload(p_record_id UUID)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_status TEXT;
  v_deleted_files_count INT;
  v_result JSON;
BEGIN
  -- Get current status
  SELECT upload_status INTO v_old_status
  FROM records
  WHERE id = p_record_id;

  -- Check if record exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Record not found with id: %', p_record_id;
  END IF;

  -- Only allow reset if currently completed
  IF v_old_status != 'completed' THEN
    RAISE EXCEPTION 'Can only reset completed uploads. Current status: %', v_old_status;
  END IF;

  -- Delete associated upload_files entries
  WITH deleted AS (
    DELETE FROM upload_files
    WHERE record_id = p_record_id
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_files_count FROM deleted;

  -- Update record: clear model_url and reset status to draft
  UPDATE records
  SET 
    model_url = NULL,
    upload_status = 'draft',
    updated_at = NOW()
  WHERE id = p_record_id;

  -- Build result
  v_result := json_build_object(
    'success', true,
    'record_id', p_record_id,
    'previous_status', v_old_status,
    'new_status', 'draft',
    'deleted_files_count', v_deleted_files_count,
    'message', 'Record reset successfully for re-upload'
  );

  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    -- Return error details
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM,
      'record_id', p_record_id
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION reset_record_for_reupload(UUID) IS 
'Resets a completed record back to draft status for re-uploading. Deletes associated upload_files and clears model_url. Uses SECURITY DEFINER to bypass immutability trigger.';

-- =============================================================================
-- 3. GRANT PERMISSIONS
-- =============================================================================

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION reset_option_for_reupload(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION reset_record_for_reupload(UUID) TO authenticated;

-- Grant execute permissions to service role (for Edge Functions)
GRANT EXECUTE ON FUNCTION reset_option_for_reupload(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION reset_record_for_reupload(UUID) TO service_role;

-- =============================================================================
-- 4. ADD RLS POLICIES FOR RPC FUNCTIONS
-- =============================================================================
-- Note: While SECURITY DEFINER bypasses RLS during execution,
-- we still need to ensure users can only reset their own options/records

-- The actual permission check should happen in the function or via RLS on options/records tables
-- Since we're using SECURITY DEFINER, the function runs with creator privileges
-- We should add a check to ensure users can only reset their own data

-- Update the functions to include permission checks
CREATE OR REPLACE FUNCTION reset_option_for_reupload(p_option_id UUID)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_status TEXT;
  v_deleted_files_count INT;
  v_project_id UUID;
  v_result JSON;
BEGIN
  -- Get current status and check permissions
  SELECT o.upload_status, o.project_id INTO v_old_status, v_project_id
  FROM project_options o
  INNER JOIN projects p ON o.project_id = p.id
  WHERE o.id = p_option_id
    AND p.user_id = auth.uid();  -- Ensure user owns the project

  -- Check if option exists and user has permission
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Option not found or you do not have permission to modify it';
  END IF;

  -- Only allow reset if currently completed
  IF v_old_status != 'completed' THEN
    RAISE EXCEPTION 'Can only reset completed uploads. Current status: %', v_old_status;
  END IF;

  -- Delete associated upload_files entries
  WITH deleted AS (
    DELETE FROM upload_files
    WHERE option_id = p_option_id
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_files_count FROM deleted;

  -- Update option: clear model_url and reset status to draft
  UPDATE project_options
  SET 
    model_url = NULL,
    upload_status = 'draft',
    updated_at = NOW()
  WHERE id = p_option_id;

  -- Build result
  v_result := json_build_object(
    'success', true,
    'option_id', p_option_id,
    'previous_status', v_old_status,
    'new_status', 'draft',
    'deleted_files_count', v_deleted_files_count,
    'message', 'Option reset successfully for re-upload'
  );

  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    -- Return error details
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM,
      'option_id', p_option_id
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION reset_record_for_reupload(p_record_id UUID)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_status TEXT;
  v_deleted_files_count INT;
  v_project_id UUID;
  v_result JSON;
BEGIN
  -- Get current status and check permissions
  SELECT r.upload_status, r.project_id INTO v_old_status, v_project_id
  FROM records r
  INNER JOIN projects p ON r.project_id = p.id
  WHERE r.id = p_record_id
    AND p.user_id = auth.uid();  -- Ensure user owns the project

  -- Check if record exists and user has permission
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Record not found or you do not have permission to modify it';
  END IF;

  -- Only allow reset if currently completed
  IF v_old_status != 'completed' THEN
    RAISE EXCEPTION 'Can only reset completed uploads. Current status: %', v_old_status;
  END IF;

  -- Delete associated upload_files entries
  WITH deleted AS (
    DELETE FROM upload_files
    WHERE entity_type = 'record' AND entity_id = p_record_id
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_files_count FROM deleted;

  -- Update record: clear record_url and reset status to draft
  UPDATE records
  SET 
    record_url = NULL,
    upload_status = 'draft',
    updated_at = NOW()
  WHERE id = p_record_id;

  -- Build result
  v_result := json_build_object(
    'success', true,
    'record_id', p_record_id,
    'previous_status', v_old_status,
    'new_status', 'draft',
    'deleted_files_count', v_deleted_files_count,
    'message', 'Record reset successfully for re-upload'
  );

  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    -- Return error details
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM,
      'record_id', p_record_id
    );
END;
$$ LANGUAGE plpgsql;
