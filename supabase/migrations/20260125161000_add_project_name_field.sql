-- Migration: Add project_name field for storage path generation
-- Description: Projects table needs a sanitized name field for creating storage paths
-- Date: 2026-01-25

-- The 'name' field already exists in projects table but we need to ensure it's used
-- for generating storage paths in the format: {project_name}_{project_id}

-- Add comment to clarify usage
COMMENT ON COLUMN projects.name IS 'Project name used for display and storage path generation (sanitized for filesystem use)';

-- Create function to generate storage path prefix for a project
-- Note: Different from existing get_project_storage_path which has different signature
CREATE OR REPLACE FUNCTION get_project_folder_name(project_id UUID)
RETURNS TEXT AS $$
DECLARE
  project_name TEXT;
  sanitized_name TEXT;
BEGIN
  SELECT name INTO project_name FROM projects WHERE id = project_id;
  
  IF project_name IS NULL THEN
    RAISE EXCEPTION 'Project not found: %', project_id;
  END IF;
  
  -- Sanitize project name for filesystem use (replace non-alphanumeric with underscore)
  sanitized_name := regexp_replace(lower(project_name), '[^a-z0-9]+', '_', 'g');
  -- Remove leading/trailing underscores
  sanitized_name := regexp_replace(sanitized_name, '^_+|_+$', '', 'g');
  
  RETURN sanitized_name || '_' || project_id::text;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_project_folder_name IS 'Generate storage folder name in format: {sanitized_project_name}_{project_id}';
