-- Migration: Create missing storage buckets
-- Description: Create models and recordings buckets for the upload pipeline
-- Date: 2026-01-25

-- =============================================================================
-- Create storage buckets
-- =============================================================================

-- Create models bucket (for option models)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'models',
  'models',
  true,  -- public bucket for reading models
  104857600,  -- 100MB limit in bytes
  ARRAY['model/gltf-binary', 'model/gltf+json', 'application/octet-stream']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 104857600,
  allowed_mime_types = ARRAY['model/gltf-binary', 'model/gltf+json', 'application/octet-stream'];

-- Create recordings bucket (for record files)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'recordings',
  'recordings',
  false,  -- private bucket, controlled by policies
  524288000,  -- 500MB limit in bytes
  ARRAY['application/json', 'model/gltf-binary', 'application/octet-stream']
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 524288000,
  allowed_mime_types = ARRAY['application/json', 'model/gltf-binary', 'application/octet-stream'];

-- =============================================================================
-- Storage policies for models bucket
-- =============================================================================

-- Authenticated users can upload models
CREATE POLICY "Authenticated users can upload to models bucket"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'models');

-- Public can read models
CREATE POLICY "Public can read from models bucket"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'models');

-- Authenticated users can update models
CREATE POLICY "Authenticated users can update models"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'models');

-- Authenticated users can delete models
CREATE POLICY "Authenticated users can delete models"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'models');

-- =============================================================================
-- Storage policies for recordings bucket
-- =============================================================================

-- Authenticated users can upload recordings
CREATE POLICY "Authenticated users can upload to recordings bucket"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'recordings');

-- Authenticated users can read their recordings
CREATE POLICY "Authenticated users can read from recordings bucket"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'recordings');

-- Public can read recordings for released projects
CREATE POLICY "Public can read recordings for released projects"
ON storage.objects FOR SELECT
TO public
USING (
  bucket_id = 'recordings'
  AND EXISTS (
    SELECT 1 
    FROM records r
    JOIN projects p ON p.id = r.project_id
    WHERE p.status = 'released'
    AND storage.objects.name LIKE 'records/' || r.id::text || '%'
  )
);

-- Authenticated users can update recordings
CREATE POLICY "Authenticated users can update recordings"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'recordings');

-- Authenticated users can delete recordings
CREATE POLICY "Authenticated users can delete recordings"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'recordings');
