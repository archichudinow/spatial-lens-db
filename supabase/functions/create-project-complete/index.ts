/**
 * Edge Function: create-project-complete
 * 
 * Creates a project with base option and base scenario in a single operation.
 * This reduces client complexity and ensures data consistency.
 * 
 * The database trigger will automatically create the Base Scenario
 * when the Base Option is created.
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ProjectData {
  name: string
  description?: string
  status?: 'development' | 'released' | 'archived'
  models_context?: string[]
  models_heatmap?: string
  spatial_lens_url?: string
  spatial_simulation_url?: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client with user's auth token
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Get request body
    const { project }: { project: ProjectData } = await req.json()

    // Validate input
    if (!project?.name?.trim()) {
      throw new Error('Project name is required')
    }

    // Step 1: Create project
    const { data: newProject, error: projectError } = await supabaseClient
      .from('projects')
      .insert([{
        name: project.name.trim(),
        description: project.description?.trim() || null,
        status: project.status || 'development',
        models_context: project.models_context || null,
        models_heatmap: project.models_heatmap || null,
        spatial_lens_url: project.spatial_lens_url || null,
        spatial_simulation_url: project.spatial_simulation_url || null,
      }])
      .select()
      .single()

    if (projectError) {
      console.error('Project creation error:', projectError)
      throw projectError
    }

    // Step 2: Create base option
    // Note: The database trigger will automatically create the Base Scenario
    const { data: baseOption, error: optionError } = await supabaseClient
      .from('project_options')
      .insert([{
        project_id: newProject.id,
        name: 'Base Option',
        description: 'Default option created with the project',
        model_url: project.models_context?.[0] || null,
        is_default: true,
        is_archived: false,
      }])
      .select()
      .single()

    if (optionError) {
      console.error('Base option creation error:', optionError)
      // Rollback: delete the project
      await supabaseClient.from('projects').delete().eq('id', newProject.id)
      throw optionError
    }

    // Step 3: Fetch complete project with nested data
    // Give the trigger a moment to complete
    await new Promise(resolve => setTimeout(resolve, 100))

    const { data: fullProject, error: fullError } = await supabaseClient
      .rpc('get_project_full', { p_project_id: newProject.id })

    if (fullError) {
      console.error('Fetch full project error:', fullError)
      // Don't rollback here - project was created successfully
      // Return basic project data instead
      return new Response(
        JSON.stringify({
          success: true,
          project: {
            ...newProject,
            options: [{
              ...baseOption,
              scenarios: []
            }]
          },
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      )
    }

    return new Response(
      JSON.stringify({
        success: true,
        project: fullProject,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Function error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Unknown error occurred',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
