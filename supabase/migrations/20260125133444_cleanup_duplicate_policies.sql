-- Migration: Cleanup Duplicate RLS Policies
-- Description: Remove old duplicate policies that were not properly cleaned up
-- This resolves performance warnings about multiple permissive policies

-- =============================================================================
-- PROJECTS TABLE - Remove old duplicate policies
-- =============================================================================

DROP POLICY IF EXISTS "Public can view all projects" ON public.projects;
DROP POLICY IF EXISTS "Public users can view released projects" ON public.projects;
DROP POLICY IF EXISTS "Authenticated users can create projects" ON public.projects;
DROP POLICY IF EXISTS "Authenticated users can update projects" ON public.projects;
DROP POLICY IF EXISTS "Authenticated users can delete projects" ON public.projects;

-- Keep only the new named policies:
-- ✅ anon_read_projects
-- ✅ authenticated_read_projects
-- ✅ authenticated_insert_projects
-- ✅ authenticated_update_projects
-- ✅ authenticated_delete_projects

-- =============================================================================
-- PROJECT_OPTIONS TABLE - Remove old duplicate policies
-- =============================================================================

DROP POLICY IF EXISTS "Public can view all project_options" ON public.project_options;
DROP POLICY IF EXISTS "Public users can view project_options" ON public.project_options;
DROP POLICY IF EXISTS "Authenticated users can create project_options" ON public.project_options;
DROP POLICY IF EXISTS "Authenticated users can update project_options" ON public.project_options;
DROP POLICY IF EXISTS "Authenticated users can delete project_options" ON public.project_options;

-- Keep only the new named policies:
-- ✅ anon_read_options
-- ✅ authenticated_read_options
-- ✅ authenticated_insert_options
-- ✅ authenticated_update_options
-- ✅ authenticated_delete_options

-- =============================================================================
-- SCENARIOS TABLE - Remove old duplicate policies
-- =============================================================================

DROP POLICY IF EXISTS "Public can view all scenarios" ON public.scenarios;
DROP POLICY IF EXISTS "Authenticated users can create scenarios" ON public.scenarios;
DROP POLICY IF EXISTS "Authenticated users can update scenarios" ON public.scenarios;
DROP POLICY IF EXISTS "Authenticated users can delete scenarios" ON public.scenarios;

-- Keep only the new named policies:
-- ✅ anon_read_scenarios
-- ✅ authenticated_read_scenarios
-- ✅ authenticated_insert_scenarios
-- ✅ authenticated_update_scenarios
-- ✅ authenticated_delete_scenarios

-- =============================================================================
-- RECORDS TABLE - Remove old duplicate policies
-- =============================================================================

DROP POLICY IF EXISTS "Public can view all records" ON public.records;
DROP POLICY IF EXISTS "Public users can view records" ON public.records;
DROP POLICY IF EXISTS "Authenticated users can update records" ON public.records;
DROP POLICY IF EXISTS "Authenticated users can delete records" ON public.records;

-- Keep only the new named policies:
-- ✅ anon_read_records
-- ✅ authenticated_read_records
-- ✅ authenticated_update_records
-- ✅ authenticated_delete_records
-- ✅ service_role_insert_records

-- =============================================================================
-- VERIFICATION COMMENT
-- =============================================================================

COMMENT ON TABLE public.projects IS 
  'Projects table with clean RLS policies: anon/authenticated can read, authenticated can write';

COMMENT ON TABLE public.project_options IS 
  'Project options table with clean RLS policies: anon/authenticated can read, authenticated can write';

COMMENT ON TABLE public.scenarios IS 
  'Scenarios table with clean RLS policies: anon/authenticated can read, authenticated can write';

COMMENT ON TABLE public.records IS 
  'Records table with clean RLS policies: anon can read, service_role can insert, authenticated can manage';
