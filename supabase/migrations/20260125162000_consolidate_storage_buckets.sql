-- Migration: Consolidate to unified projects bucket with hierarchical structure
-- Description: Implement the hierarchical storage structure from STORAGE_UPDATE.md
-- Date: 2026-01-25

-- =============================================================================
-- CLEANUP: Remove old separate buckets (if they exist)
-- =============================================================================

-- Drop old policies from models bucket
DROP POLICY IF EXISTS "Authenticated users can delete models" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update models" ON storage.objects;
DROP POLICY IF EXISTS "Public can read from models bucket" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload to models bucket" ON storage.objects;

-- Drop old policies from recordings bucket
DROP POLICY IF EXISTS "Authenticated users can delete recordings" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update recordings" ON storage.objects;
DROP POLICY IF EXISTS "Public can read recordings for released projects" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can read from recordings bucket" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload to recordings bucket" ON storage.objects;

-- Note: We don't delete the actual buckets to preserve any existing files
-- Manual cleanup can be done if needed: DELETE FROM storage.buckets WHERE id IN ('models', 'recordings');

-- =============================================================================
-- CREATE: Unified projects bucket
-- =============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'projects',
  'projects',
  true,  -- public for reading files
  524288000,  -- 500MB limit (larger than before to accommodate all file types)
  ARRAY[
    'model/gltf-binary',
    'model/gltf+json',
    'application/octet-stream',
    'application/json',
    'text/csv'
  ]
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 524288000,
  allowed_mime_types = ARRAY[
    'model/gltf-binary',
    'model/gltf+json',
    'application/octet-stream',
    'application/json',
    'text/csv'
  ];

-- =============================================================================
-- STORAGE POLICIES: Hierarchical structure access control
-- =============================================================================

-- Drop existing policies to recreate with new structure
DROP POLICY IF EXISTS "service_role_insert_storage" ON storage.objects;
DROP POLICY IF EXISTS "authenticated_read_storage" ON storage.objects;
DROP POLICY IF EXISTS "anon_read_storage" ON storage.objects;

-- Public/Anon can read all files from projects bucket
CREATE POLICY "public_read_projects_bucket"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'projects');

-- Authenticated users can read all files
CREATE POLICY "authenticated_read_projects_bucket"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (bucket_id = 'projects');

-- Only service_role (Edge Functions) can INSERT files
-- This ensures all uploads go through the proper pipeline
CREATE POLICY "service_role_insert_projects_bucket"
  ON storage.objects
  FOR INSERT
  TO service_role
  WITH CHECK (bucket_id = 'projects');

-- Service role can update files (for chunked uploads)
CREATE POLICY "service_role_update_projects_bucket"
  ON storage.objects
  FOR UPDATE
  TO service_role
  USING (bucket_id = 'projects');

-- Service role can delete files
CREATE POLICY "service_role_delete_projects_bucket"
  ON storage.objects
  FOR DELETE
  TO service_role
  USING (bucket_id = 'projects');

-- =============================================================================
-- HELPER FUNCTIONS: Storage path generation
-- =============================================================================

-- Function to generate option model path
CREATE OR REPLACE FUNCTION generate_option_model_path(
  p_project_id UUID,
  p_option_id UUID,
  p_timestamp BIGINT DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
  project_path TEXT;
  ts BIGINT;
BEGIN
  project_path := get_project_folder_name(p_project_id);
  ts := COALESCE(p_timestamp, extract(epoch from now())::bigint * 1000);
  
  RETURN project_path || '/options/' || p_option_id::text || '/model_' || ts::text || '.glb';
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to generate record GLB path
CREATE OR REPLACE FUNCTION generate_record_glb_path(
  p_project_id UUID,
  p_option_id UUID,
  p_scenario_id UUID,
  p_timestamp BIGINT DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
  project_path TEXT;
  ts BIGINT;
BEGIN
  project_path := get_project_folder_name(p_project_id);
  ts := COALESCE(p_timestamp, extract(epoch from now())::bigint * 1000);
  
  RETURN project_path || '/records/records_glb/' || p_option_id::text || '/' || p_scenario_id::text || '/processed_recording_' || ts::text || '.glb';
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to generate record JSON/CSV path
CREATE OR REPLACE FUNCTION generate_record_raw_path(
  p_project_id UUID,
  p_option_id UUID,
  p_scenario_id UUID,
  p_timestamp BIGINT DEFAULT NULL,
  p_extension TEXT DEFAULT 'json'
)
RETURNS TEXT AS $$
DECLARE
  project_path TEXT;
  ts BIGINT;
BEGIN
  project_path := get_project_folder_name(p_project_id);
  ts := COALESCE(p_timestamp, extract(epoch from now())::bigint * 1000);
  
  RETURN project_path || '/records/records_csv/' || p_option_id::text || '/' || p_scenario_id::text || '/raw_recording_' || ts::text || '.' || p_extension;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to generate project context/heatmap path
CREATE OR REPLACE FUNCTION generate_project_other_path(
  p_project_id UUID,
  p_file_type TEXT, -- 'context' or 'heatmap'
  p_timestamp BIGINT DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
  project_path TEXT;
  ts BIGINT;
BEGIN
  project_path := get_project_folder_name(p_project_id);
  ts := COALESCE(p_timestamp, extract(epoch from now())::bigint * 1000);
  
  RETURN project_path || '/others/' || p_file_type || '_' || ts::text || '.glb';
END;
$$ LANGUAGE plpgsql STABLE;

-- Add comments
COMMENT ON FUNCTION generate_option_model_path IS 'Generate storage path for option 3D models: {project}/options/{option}/model_{ts}.glb';
COMMENT ON FUNCTION generate_record_glb_path IS 'Generate storage path for processed recordings: {project}/records/records_glb/{option}/{scenario}/processed_recording_{ts}.glb';
COMMENT ON FUNCTION generate_record_raw_path IS 'Generate storage path for raw recording data: {project}/records/records_csv/{option}/{scenario}/raw_recording_{ts}.json';
COMMENT ON FUNCTION generate_project_other_path IS 'Generate storage path for project-level files: {project}/others/{type}_{ts}.glb';
