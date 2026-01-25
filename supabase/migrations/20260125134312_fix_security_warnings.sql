-- Migration: Fix Security Warnings
-- Description:
--   1. Set search_path on all functions to prevent privilege escalation
--   2. Remove "Public can create records" policy (anons should only write via Edge Functions)

-- =============================================================================
-- 1. FIX: Set search_path on all functions for security
-- =============================================================================

-- Fix: auto_create_exploration_scenario (existing function)
CREATE OR REPLACE FUNCTION public.auto_create_exploration_scenario()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO scenarios (
    option_id,
    name,
    description,
    objective,
    start_coordinates,
    destination_coordinates,
    is_archived
  ) VALUES (
    NEW.id,
    CASE 
      WHEN NEW.is_default THEN 'Base Scenario'
      ELSE 'Exploration Scenario'
    END,
    'A free exploration scenario created with the option',
    'You are free to explore',
    '{"x": 0, "y": 0, "z": 0}'::jsonb,
    '{"x": 0, "y": 0, "z": 0}'::jsonb,
    false
  );
  
  RETURN NEW;
END;
$$;

-- Fix: update_updated_at_column (existing function)
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- Fix: auto_create_base_option
CREATE OR REPLACE FUNCTION public.auto_create_base_option()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO project_options (
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

-- Fix: prevent_base_option_deletion
CREATE OR REPLACE FUNCTION public.prevent_base_option_deletion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  project_exists BOOLEAN;
BEGIN
  IF OLD.is_default = true THEN
    SELECT EXISTS(SELECT 1 FROM projects WHERE id = OLD.project_id) INTO project_exists;
    
    IF project_exists THEN
      RAISE EXCEPTION 'Cannot delete base option while project exists';
    END IF;
  END IF;
  
  RETURN OLD;
END;
$$;

-- Fix: prevent_base_scenario_deletion
CREATE OR REPLACE FUNCTION public.prevent_base_scenario_deletion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  scenario_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO scenario_count
  FROM scenarios
  WHERE option_id = OLD.option_id AND is_archived = false;
  
  IF scenario_count <= 1 THEN
    RAISE EXCEPTION 'Cannot delete base scenario. Each option must have at least one scenario.';
  END IF;
  
  RETURN OLD;
END;
$$;

-- Fix: cascade_delete_project
CREATE OR REPLACE FUNCTION public.cascade_delete_project()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM records WHERE project_id = OLD.id;
  
  DELETE FROM scenarios 
  WHERE option_id IN (
    SELECT id FROM project_options WHERE project_id = OLD.id
  );
  
  DELETE FROM project_options WHERE project_id = OLD.id;
  
  RETURN OLD;
END;
$$;

-- Fix: get_project_storage_path
CREATE OR REPLACE FUNCTION public.get_project_storage_path(
  p_project_id UUID,
  p_file_type TEXT,
  p_option_id UUID DEFAULT NULL,
  p_scenario_id UUID DEFAULT NULL,
  p_record_id UUID DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  base_path TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM projects WHERE id = p_project_id) THEN
    RAISE EXCEPTION 'Project not found';
  END IF;
  
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

-- Fix: get_project_full (existing function)
CREATE OR REPLACE FUNCTION public.get_project_full(p_project_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'id', p.id,
    'name', p.name,
    'description', p.description,
    'status', p.status,
    'models_context', p.models_context,
    'models_heatmap', p.models_heatmap,
    'spatial_lens_url', p.spatial_lens_url,
    'spatial_simulation_url', p.spatial_simulation_url,
    'created_at', p.created_at,
    'updated_at', p.updated_at,
    'options', (
      SELECT json_agg(json_build_object(
        'id', o.id,
        'name', o.name,
        'description', o.description,
        'model_url', o.model_url,
        'is_archived', o.is_archived,
        'created_at', o.created_at,
        'scenarios', (
          SELECT json_agg(json_build_object(
            'id', s.id,
            'name', s.name,
            'description', s.description,
            'objective', s.objective,
            'start_coordinates', s.start_coordinates,
            'destination_coordinates', s.destination_coordinates,
            'is_archived', s.is_archived,
            'records_count', (
              SELECT count(*) FROM records r
              WHERE r.scenario_id = s.id AND r.is_archived = false
            )
          ))
          FROM scenarios s
          WHERE s.option_id = o.id AND s.is_archived = false
        )
      ))
      FROM project_options o
      WHERE o.project_id = p.id AND o.is_archived = false
    )
  ) INTO result
  FROM projects p
  WHERE p.id = p_project_id;
  
  RETURN result;
END;
$$;

-- =============================================================================
-- 2. REMOVE: "Public can create records" policy (anons should use Edge Functions)
-- =============================================================================

DROP POLICY IF EXISTS "Public can create records" ON public.records;

-- Ensure only service_role can insert records (Edge Functions)
-- The service_role_insert_records policy already handles this correctly

-- =============================================================================
-- COMMENTS: Document the security fixes
-- =============================================================================

COMMENT ON FUNCTION public.auto_create_exploration_scenario() IS 
  'Automatically creates scenarios when options are created. Uses SET search_path = public for security.';

COMMENT ON FUNCTION public.update_updated_at_column() IS 
  'Updates updated_at timestamp on row changes. Uses SET search_path = public for security.';

COMMENT ON FUNCTION public.auto_create_base_option() IS 
  'Creates base option when project is created. Uses SET search_path = public for security.';

COMMENT ON FUNCTION public.prevent_base_option_deletion() IS 
  'Prevents deletion of base option while project exists. Uses SET search_path = public for security.';

COMMENT ON FUNCTION public.prevent_base_scenario_deletion() IS 
  'Prevents deletion of last scenario for an option. Uses SET search_path = public for security.';

COMMENT ON FUNCTION public.cascade_delete_project() IS 
  'Cascades deletion to all related data. Uses SET search_path = public for security.';

COMMENT ON FUNCTION public.get_project_storage_path(UUID, TEXT, UUID, UUID, UUID) IS 
  'Generates consistent storage paths for project files. Uses SET search_path = public for security.';

COMMENT ON FUNCTION public.get_project_full(UUID) IS 
  'Returns complete project data with options and scenarios. Uses SET search_path = public for security.';
