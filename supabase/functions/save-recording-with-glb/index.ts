/**
 * Supabase Edge Function: save-recording-with-glb
 * 
 * Alternative approach: Client generates GLB, sends it with metadata to server.
 * Server handles upload and database record creation.
 * 
 * Use this if you want to keep Three.js GLB generation on client side.
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface Frame {
  time: number
  position: { x: number; y: number; z: number }
  lookAt: { x: number; y: number; z: number }
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client with service role
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Parse multipart form data
    const formData = await req.formData()
    
    const projectId = formData.get('projectId') as string
    const optionId = formData.get('optionId') as string
    const scenarioId = formData.get('scenarioId') as string
    const optionName = formData.get('optionName') as string
    const scenarioName = formData.get('scenarioName') as string
    const deviceType = (formData.get('deviceType') as string) || 'pc'
    const durationMs = parseInt(formData.get('durationMs') as string)
    
    const glbFile = formData.get('glbFile') as File
    const csvFile = formData.get('csvFile') as File | null

    // Validate required fields
    if (!projectId || !optionId || !scenarioId || !glbFile) {
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: projectId, optionId, scenarioId, glbFile' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Verify entities exist
    const { data: project, error: projectError } = await supabaseClient
      .from('projects')
      .select('id')
      .eq('id', projectId)
      .single()

    if (projectError || !project) {
      return new Response(
        JSON.stringify({ error: 'Project not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { data: option, error: optionError } = await supabaseClient
      .from('project_options')
      .select('id, name')
      .eq('id', optionId)
      .single()

    if (optionError || !option) {
      return new Response(
        JSON.stringify({ error: 'Option not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { data: scenario, error: scenarioError } = await supabaseClient
      .from('scenarios')
      .select('id, name')
      .eq('id', scenarioId)
      .single()

    if (scenarioError || !scenario) {
      return new Response(
        JSON.stringify({ error: 'Scenario not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Generate file names
    const sanitizedOption = (optionName || option.name).replace(/[^a-zA-Z0-9]/g, '_')
    const sanitizedScenario = (scenarioName || scenario.name).replace(/[^a-zA-Z0-9]/g, '_')
    const uniqueId = Date.now()
    const baseFileName = `${sanitizedOption}_${sanitizedScenario}_${uniqueId}`

    // Upload GLB to storage
    const glbPath = `${projectId}/records/${baseFileName}.glb`
    const glbArrayBuffer = await glbFile.arrayBuffer()
    const { data: glbUpload, error: glbError } = await supabaseClient.storage
      .from('projects')
      .upload(glbPath, glbArrayBuffer, {
        contentType: 'model/gltf-binary',
        upsert: false
      })

    if (glbError) {
      console.error('GLB upload error:', glbError)
      return new Response(
        JSON.stringify({ error: 'Failed to upload GLB file', details: glbError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get public URL for GLB
    const { data: glbUrlData } = supabaseClient.storage
      .from('projects')
      .getPublicUrl(glbPath)

    // Upload CSV if provided
    let rawUrl = null
    if (csvFile) {
      const csvPath = `${projectId}/records/${baseFileName}.csv`
      const csvArrayBuffer = await csvFile.arrayBuffer()
      const { data: csvUpload, error: csvError } = await supabaseClient.storage
        .from('projects')
        .upload(csvPath, csvArrayBuffer, {
          contentType: 'text/csv',
          upsert: false
        })

      if (!csvError) {
        const { data: csvUrlData } = supabaseClient.storage
          .from('projects')
          .getPublicUrl(csvPath)
        rawUrl = csvUrlData.publicUrl
      }
    }

    // Create database record
    const { data: record, error: recordError } = await supabaseClient
      .from('records')
      .insert({
        project_id: projectId,
        option_id: optionId,
        scenario_id: scenarioId,
        record_url: glbUrlData.publicUrl,
        raw_url: rawUrl,
        length_ms: durationMs,
        device_type: deviceType,
        is_archived: false,
      })
      .select()
      .single()

    if (recordError) {
      console.error('Database error:', recordError)
      // Clean up uploaded files
      const filesToRemove = [glbPath]
      if (rawUrl) filesToRemove.push(`${projectId}/records/${baseFileName}.csv`)
      await supabaseClient.storage.from('projects').remove(filesToRemove)
      
      return new Response(
        JSON.stringify({ error: 'Failed to create database record', details: recordError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Success response
    return new Response(
      JSON.stringify({
        success: true,
        record,
        glbUrl: glbUrlData.publicUrl,
        rawUrl,
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Edge function error:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
