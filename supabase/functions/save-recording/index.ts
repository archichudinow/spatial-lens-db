/**
 * Supabase Edge Function: save-recording
 * 
 * Accepts recording frame data from client, generates GLB and CSV files,
 * uploads to storage, and creates database record.
 * 
 * This approach keeps storage write permissions server-side only.
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

interface RecordingRequest {
  projectId: string
  optionId: string
  scenarioId: string
  optionName: string
  scenarioName: string
  deviceType: 'pc' | 'vr'
  frames: Frame[]
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client with service role (has full access)
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

    // Parse request body
    const body: RecordingRequest = await req.json()
    const {
      projectId,
      optionId,
      scenarioId,
      optionName,
      scenarioName,
      deviceType,
      frames
    } = body

    // Validate required fields
    if (!projectId || !optionId || !scenarioId || !frames || frames.length === 0) {
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: projectId, optionId, scenarioId, frames' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Verify that project, option, and scenario exist
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

    // Calculate duration
    const durationMs = Math.round((frames[frames.length - 1]?.time || 0) * 1000)

    // Generate file names
    const sanitizedOption = (optionName || option.name).replace(/[^a-zA-Z0-9]/g, '_')
    const sanitizedScenario = (scenarioName || scenario.name).replace(/[^a-zA-Z0-9]/g, '_')
    const uniqueId = Date.now()
    const baseFileName = `${sanitizedOption}_${sanitizedScenario}_${uniqueId}`

    // Generate CSV content
    const csvContent = generateCSV(frames)
    const csvBlob = new Blob([csvContent], { type: 'text/csv' })

    // Generate simplified GLB content
    // Note: This is a simplified version. For full Three.js GLB export, 
    // consider keeping client-side generation or using a GLB library
    const glbContent = generateSimplifiedGLB(frames, {
      optionName: option.name,
      scenarioName: scenario.name,
    })
    const glbBlob = new Blob([glbContent], { type: 'application/octet-stream' })

    // Upload GLB to storage
    const glbPath = `${projectId}/records/${baseFileName}.glb`
    const { data: glbUpload, error: glbError } = await supabaseClient.storage
      .from('projects')
      .upload(glbPath, glbBlob, {
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

    // Upload CSV to storage
    const csvPath = `${projectId}/records/${baseFileName}.csv`
    const { data: csvUpload, error: csvError } = await supabaseClient.storage
      .from('projects')
      .upload(csvPath, csvBlob, {
        contentType: 'text/csv',
        upsert: false
      })

    let rawUrl = null
    if (!csvError) {
      const { data: csvUrlData } = supabaseClient.storage
        .from('projects')
        .getPublicUrl(csvPath)
      rawUrl = csvUrlData.publicUrl
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
        device_type: deviceType || 'pc',
        is_archived: false,
      })
      .select()
      .single()

    if (recordError) {
      console.error('Database error:', recordError)
      // Try to clean up uploaded files
      await supabaseClient.storage.from('projects').remove([glbPath, csvPath])
      
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

/**
 * Generate CSV content from frames
 */
function generateCSV(frames: Frame[]): string {
  const header = 'time,position_x,position_y,position_z,lookAt_x,lookAt_y,lookAt_z\n'
  const rows = frames.map(frame => 
    `${frame.time},${frame.position.x},${frame.position.y},${frame.position.z},${frame.lookAt.x},${frame.lookAt.y},${frame.lookAt.z}`
  ).join('\n')
  return header + rows
}

/**
 * Generate a simplified GLB file
 * NOTE: This creates a minimal JSON representation of the recording.
 * For proper Three.js GLB format, you should:
 * 1. Keep client-side GLB generation OR
 * 2. Use a Deno-compatible GLB library OR
 * 3. Send the GLB blob from client to this function
 */
function generateSimplifiedGLB(frames: Frame[], metadata: any): Uint8Array {
  // This is a JSON representation - not actual GLB format
  // You can either:
  // A) Keep GLB generation client-side and send blob to function
  // B) Implement proper GLB encoding here
  // C) Use this JSON format and update your viewer to read it
  
  const data = {
    metadata,
    frames,
    version: '1.0',
    type: 'recording'
  }
  
  const jsonString = JSON.stringify(data)
  return new TextEncoder().encode(jsonString)
}
