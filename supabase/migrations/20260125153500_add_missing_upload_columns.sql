-- Migration: Add missing upload columns to project_options
-- Description: Add upload_error and upload_retry_count columns to project_options
-- Date: 2026-01-25

-- =============================================================================
-- Add missing columns to project_options
-- =============================================================================

ALTER TABLE project_options
  ADD COLUMN IF NOT EXISTS upload_error TEXT,
  ADD COLUMN IF NOT EXISTS upload_retry_count INTEGER DEFAULT 0;

COMMENT ON COLUMN project_options.upload_error IS 'Error message if upload failed';
COMMENT ON COLUMN project_options.upload_retry_count IS 'Number of times upload has been retried';

-- Similarly add to projects table if not already there
ALTER TABLE projects
  ADD COLUMN IF NOT EXISTS upload_error TEXT,
  ADD COLUMN IF NOT EXISTS upload_retry_count INTEGER DEFAULT 0;

COMMENT ON COLUMN projects.upload_error IS 'Error message if upload failed';
COMMENT ON COLUMN projects.upload_retry_count IS 'Number of times upload has been retried';
