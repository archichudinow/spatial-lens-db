/**
 * Edge Function: create-option-complete
 * 
 * Creates an option with exploration scenario automatically.
 * The database trigger handles the scenario creation.
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface OptionData {
  project_id: string
  name: string
  description?: string
  model_url?: string
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
    const { option }: { option: OptionData } = await req.json()

    // Validate input
    if (!option?.project_id || !option?.name?.trim()) {
      throw new Error('Project ID and option name are required')
    }

    // Verify project exists
    const { data: project, error: projectCheckError } = await supabaseClient
      .from('projects')
      .select('id')
      .eq('id', option.project_id)
      .single()

    if (projectCheckError || !project) {
      throw new Error('Project not found')
    }

    // Create option - trigger will auto-create exploration scenario
    const { data: newOption, error: optionError } = await supabaseClient
      .from('project_options')
      .insert([{
        project_id: option.project_id,
        name: option.name.trim(),
        description: option.description?.trim() || null,
        model_url: option.model_url || null,
        is_default: false,
        is_archived: false,
      }])
      .select()
      .single()

    if (optionError) {
      console.error('Option creation error:', optionError)
      throw optionError
    }

    // Give the trigger a moment to create the scenario
    await new Promise(resolve => setTimeout(resolve, 100))

    // Fetch the option with its scenarios
    const { data: scenarios, error: scenariosError } = await supabaseClient
      .from('scenarios')
      .select('*')
      .eq('option_id', newOption.id)
      .eq('is_archived', false)
      .order('created_at', { ascending: true })

    if (scenariosError) {
      console.error('Scenarios fetch error:', scenariosError)
      // Return option without scenarios if fetch fails
      return new Response(
        JSON.stringify({
          success: true,
          option: {
            ...newOption,
            scenarios: [],
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
        option: {
          ...newOption,
          scenarios: scenarios || [],
        },
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