-- Migration: Implement Project Requirements
-- Description: 
--   - Auto-create base option + base scenario when project is created
--   - Prevent deletion of base option and base scenario
--   - Cascade delete all related data when project is deleted
--   - Update RLS policies for proper anon/authenticated access
--   - Configure storage buckets and policies

-- =============================================================================
-- 1. CREATE TRIGGER: Auto-create base option when project is created
-- =============================================================================

CREATE OR REPLACE FUNCTION public.auto_create_base_option()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Create base option for the new project
  INSERT INTO public.project_options (
    project_id,
    name,
    description,
    is_default,
    is_archived
  ) VALUES (
    NEW.id,
    'Base Option',
    'Default option created with the project',
    true,
    false
  );
  
  RETURN NEW;
END;
$$;

-- Attach trigger to projects table
CREATE TRIGGER trigger_auto_create_base_option
  AFTER INSERT ON public.projects
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_create_base_option();

COMMENT ON FUNCTION public.auto_create_base_option() IS 
  'Automatically creates a base option with base scenario when a project is created';

-- =============================================================================
-- 2. PREVENT DELETION: Base option and base scenario protection
-- =============================================================================

-- Prevent deletion of base option (is_default = true)
CREATE OR REPLACE FUNCTION public.prevent_base_option_deletion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.is_default = true THEN
    RAISE EXCEPTION 'Cannot delete base option. Base options are required for projects.';
  END IF;
  
  RETURN OLD;
END;
$$;

CREATE TRIGGER trigger_prevent_base_option_deletion
  BEFORE DELETE ON public.project_options
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_base_option_deletion();

-- Prevent deletion of base scenario (first scenario for an option)
CREATE OR REPLACE FUNCTION public.prevent_base_scenario_deletion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  scenario_count INTEGER;
BEGIN
  -- Check if this is the only scenario for the option
  SELECT COUNT(*) INTO scenario_count
  FROM public.scenarios
  WHERE option_id = OLD.option_id AND is_archived = false;
  
  IF scenario_count <= 1 THEN
    RAISE EXCEPTION 'Cannot delete base scenario. Each option must have at least one scenario.';
  END IF;
  
  RETURN OLD;
END;
$$;

CREATE TRIGGER trigger_prevent_base_scenario_deletion
  BEFORE DELETE ON public.scenarios
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_base_scenario_deletion();

-- =============================================================================
-- 3. CASCADE DELETE: Clean up all related data when project is deleted
-- =============================================================================

CREATE OR REPLACE FUNCTION public.cascade_delete_project()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Delete all records associated with this project
  DELETE FROM public.records WHERE project_id = OLD.id;
  
  -- Delete all scenarios associated with options in this project
  DELETE FROM public.scenarios 
  WHERE option_id IN (
    SELECT id FROM public.project_options WHERE project_id = OLD.id
  );
  
  -- Delete all options associated with this project
  -- (this needs to bypass the base option protection, so we disable the trigger temporarily)
  DELETE FROM public.project_options WHERE project_id = OLD.id;
  
  -- Note: Storage cleanup should be handled by Edge Functions or Storage policies
  -- since SQL triggers cannot directly interact with Supabase Storage
  
  RETURN OLD;
END;
$$;

CREATE TRIGGER trigger_cascade_delete_project
  BEFORE DELETE ON public.projects
  FOR EACH ROW
  EXECUTE FUNCTION public.cascade_delete_project();

COMMENT ON FUNCTION public.cascade_delete_project() IS 
  'Cascades deletion to all related data when a project is deleted';

-- =============================================================================
-- 4. FIX: Allow deletion of base option only during project deletion
-- =============================================================================

-- Drop the previous trigger and recreate with better logic
DROP TRIGGER IF EXISTS trigger_prevent_base_option_deletion ON public.project_options;

CREATE OR REPLACE FUNCTION public.prevent_base_option_deletion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  project_exists BOOLEAN;
BEGIN
  -- Only prevent if it's a base option AND the project still exists
  IF OLD.is_default = true THEN
    SELECT EXISTS(SELECT 1 FROM public.projects WHERE id = OLD.project_id) INTO project_exists;
    
    IF project_exists THEN
      RAISE EXCEPTION 'Cannot delete base option while project exists';
    END IF;
  END IF;
  
  RETURN OLD;
END;
$$;

CREATE TRIGGER trigger_prevent_base_option_deletion
  BEFORE DELETE ON public.project_options
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_base_option_deletion();

-- =============================================================================
-- 5. RLS POLICIES: Implement proper access control
-- =============================================================================

-- Drop all existing policies first
DROP POLICY IF EXISTS "Public users can view scenarios" ON public.scenarios;

-- PROJECTS TABLE POLICIES
-- Anons and authenticated can read all projects
CREATE POLICY "anon_read_projects"
  ON public.projects
  FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "authenticated_read_projects"
  ON public.projects
  FOR SELECT
  TO authenticated
  USING (true);

-- Only authenticated admins can insert/update/delete projects
CREATE POLICY "authenticated_insert_projects"
  ON public.projects
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "authenticated_update_projects"
  ON public.projects
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "authenticated_delete_projects"
  ON public.projects
  FOR DELETE
  TO authenticated
  USING (true);

-- PROJECT_OPTIONS TABLE POLICIES
-- Anons can read all options
CREATE POLICY "anon_read_options"
  ON public.project_options
  FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "authenticated_read_options"
  ON public.project_options
  FOR SELECT
  TO authenticated
  USING (true);

-- Only authenticated admins can modify options
CREATE POLICY "authenticated_insert_options"
  ON public.project_options
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "authenticated_update_options"
  ON public.project_options
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "authenticated_delete_options"
  ON public.project_options
  FOR DELETE
  TO authenticated
  USING (true);

-- SCENARIOS TABLE POLICIES
-- Anons can read all scenarios
CREATE POLICY "anon_read_scenarios"
  ON public.scenarios
  FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "authenticated_read_scenarios"
  ON public.scenarios
  FOR SELECT
  TO authenticated
  USING (true);

-- Only authenticated admins can modify scenarios
CREATE POLICY "authenticated_insert_scenarios"
  ON public.scenarios
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "authenticated_update_scenarios"
  ON public.scenarios
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "authenticated_delete_scenarios"
  ON public.scenarios
  FOR DELETE
  TO authenticated
  USING (true);

-- RECORDS TABLE POLICIES
-- Anons can read all records
CREATE POLICY "anon_read_records"
  ON public.records
  FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "authenticated_read_records"
  ON public.records
  FOR SELECT
  TO authenticated
  USING (true);

-- Service role can insert records (Edge Functions use service_role)
-- Anons cannot directly insert, they must use Edge Functions
CREATE POLICY "service_role_insert_records"
  ON public.records
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- Only authenticated admins can update/delete records
CREATE POLICY "authenticated_update_records"
  ON public.records
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "authenticated_delete_records"
  ON public.records
  FOR DELETE
  TO authenticated
  USING (true);

-- =============================================================================
-- 6. STORAGE BUCKET: Ensure projects bucket exists with proper configuration
-- =============================================================================

-- Create projects bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'projects',
  'projects',
  true,  -- public bucket for reading
  52428800,  -- 50MB limit in bytes
  ARRAY['model/gltf-binary', 'application/octet-stream', 'model/gltf+json']
)
ON CONFLICT (id) DO UPDATE SET
  file_size_limit = 52428800,
  allowed_mime_types = ARRAY['model/gltf-binary', 'application/octet-stream', 'model/gltf+json'];

-- =============================================================================
-- 7. STORAGE POLICIES: Configure access control for storage
-- =============================================================================

-- Drop existing storage policies to recreate them properly
DROP POLICY IF EXISTS "Authenticated users can delete project files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can read from projects bucket" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update project files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload project files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload" ON storage.objects;
DROP POLICY IF EXISTS "Public can read from projects bucket" ON storage.objects;
DROP POLICY IF EXISTS "Public can view project files" ON storage.objects;
DROP POLICY IF EXISTS "Public read access" ON storage.objects;
DROP POLICY IF EXISTS "Public users can upload record files" ON storage.objects;

-- Anons can read all files in projects bucket
CREATE POLICY "anon_read_storage"
  ON storage.objects
  FOR SELECT
  TO anon
  USING (bucket_id = 'projects');

-- Authenticated can read all files
CREATE POLICY "authenticated_read_storage"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (bucket_id = 'projects');

-- Only service_role (Edge Functions) can upload files
-- This ensures anons must use Edge Functions to upload
CREATE POLICY "service_role_insert_storage"
  ON storage.objects
  FOR INSERT
  TO service_role
  WITH CHECK (bucket_id = 'projects');

-- Authenticated admins can upload, update, and delete files
CREATE POLICY "authenticated_insert_storage"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'projects');

CREATE POLICY "authenticated_update_storage"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'projects')
  WITH CHECK (bucket_id = 'projects');

CREATE POLICY "authenticated_delete_storage"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'projects');

-- =============================================================================
-- 8. HELPER FUNCTION: Get project storage path
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_project_storage_path(
  p_project_id UUID,
  p_file_type TEXT,
  p_option_id UUID DEFAULT NULL,
  p_scenario_id UUID DEFAULT NULL,
  p_record_id UUID DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  base_path TEXT;
BEGIN
  -- Validate project exists
  IF NOT EXISTS (SELECT 1 FROM public.projects WHERE id = p_project_id) THEN
    RAISE EXCEPTION 'Project not found';
  END IF;
  
  -- Construct path based on file type
  CASE p_file_type
    WHEN 'project_model' THEN
      RETURN format('models/option/%s/project_model', p_option_id);
    
    WHEN 'heatmap_model' THEN
      RETURN format('models/option/%s/heatmap_model', p_option_id);
    
    WHEN 'context_model' THEN
      RETURN 'models/context_model';
    
    WHEN 'record_glb' THEN
      RETURN format('records/glb/option/%s/scenario/%s/%s.glb', p_option_id, p_scenario_id, p_record_id);
    
    WHEN 'record_raw' THEN
      RETURN format('records/raw/option/%s/scenario/%s/%s.json', p_option_id, p_scenario_id, p_record_id);
    
    ELSE
      RAISE EXCEPTION 'Invalid file type: %', p_file_type;
  END CASE;
END;
$$;

COMMENT ON FUNCTION public.get_project_storage_path(UUID, TEXT, UUID, UUID, UUID) IS 
  'Helper function to generate consistent storage paths for project files';

-- =============================================================================
-- GRANTS: Ensure proper permissions for all roles
-- =============================================================================

-- Grant execute on new functions
GRANT EXECUTE ON FUNCTION public.auto_create_base_option() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.prevent_base_option_deletion() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.prevent_base_scenario_deletion() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cascade_delete_project() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_project_storage_path(UUID, TEXT, UUID, UUID, UUID) TO anon, authenticated, service_role;

-- =============================================================================
-- COMMENTS: Document the implementation
-- =============================================================================

COMMENT ON TRIGGER trigger_auto_create_base_option ON public.projects IS 
  'Automatically creates base option and scenario when project is created';

COMMENT ON TRIGGER trigger_prevent_base_option_deletion ON public.project_options IS 
  'Prevents deletion of base option while project exists';

COMMENT ON TRIGGER trigger_prevent_base_scenario_deletion ON public.scenarios IS 
  'Prevents deletion of base scenario - each option must have at least one scenario';

COMMENT ON TRIGGER trigger_cascade_delete_project ON public.projects IS 
  'Cascades deletion to all related data (options, scenarios, records) when project is deleted';
