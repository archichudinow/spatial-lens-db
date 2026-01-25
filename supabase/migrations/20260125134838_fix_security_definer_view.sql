-- Migration: Fix Security Definer View
-- Description: Change projects_full view from SECURITY DEFINER to SECURITY INVOKER
-- This ensures RLS policies are properly enforced based on the querying user

-- Drop and recreate the view with SECURITY INVOKER (default safe behavior)
DROP VIEW IF EXISTS public.projects_full;

CREATE VIEW public.projects_full
WITH (security_invoker = true)
AS
 SELECT p.id,
    p.name,
    p.description,
    p.status,
    p.models_context,
    p.models_heatmap,
    p.spatial_lens_url,
    p.spatial_simulation_url,
    p.created_at,
    p.updated_at,
    ( SELECT json_agg(jsonb_build_object(
        'id', o.id,
        'name', o.name,
        'description', o.description,
        'model_url', o.model_url,
        'is_archived', o.is_archived,
        'created_at', o.created_at,
        'scenarios', ( SELECT json_agg(jsonb_build_object(
            'id', s.id,
            'name', s.name,
            'description', s.description,
            'objective', s.objective,
            'start_coordinates', s.start_coordinates,
            'destination_coordinates', s.destination_coordinates,
            'is_archived', s.is_archived,
            'records_count', ( SELECT count(*) AS count
                FROM public.records r
                WHERE r.scenario_id = s.id AND r.is_archived = false
            )
          ))
          FROM public.scenarios s
          WHERE s.option_id = o.id AND s.is_archived = false
        )
      ))
      FROM public.project_options o
      WHERE o.project_id = p.id AND o.is_archived = false
    ) AS options
   FROM public.projects p;

ALTER VIEW public.projects_full OWNER TO postgres;

COMMENT ON VIEW public.projects_full IS 
  'View with SECURITY INVOKER - enforces RLS policies of the querying user, not the view creator';

-- Ensure the view is accessible to all roles (since underlying tables already have RLS)
GRANT SELECT ON public.projects_full TO anon;
GRANT SELECT ON public.projects_full TO authenticated;
GRANT SELECT ON public.projects_full TO service_role;
