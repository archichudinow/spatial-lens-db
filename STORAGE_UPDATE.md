# Storage Bucket Structure

## Overview

All files are now stored in the **`projects`** bucket with a hierarchical structure organized by project.

## Structure

```
projects/
  {project_name}_{project_id}/
    options/
      {option_id}/
        model_1234567890.glb
        model_1234567891.glb
    
    records/
      records_glb/
        {option_id}/
          {scenario_id}/
            processed_recording_1234567890.glb
            processed_recording_1234567891.glb
      
      records_csv/
        {option_id}/
          {scenario_id}/
            raw_recording_1234567890.json
            raw_recording_1234567891.json
    
    others/
      context_1234567890.glb
      heatmap_1234567891.glb
```

## Folder Descriptions

### `{project_name}_{project_id}/`
- **Root folder** for each project
- Combines project name with ID for easy identification
- Example: `spatial_analysis_abc-123-def/`

### `options/{option_id}/`
- Contains **3D models** for each option (Option A, B, C, etc.)
- One subfolder per option
- Files: `model_{timestamp}.glb`

### `records/records_glb/{option_id}/{scenario_id}/`
- Contains **processed .glb recording files**
- Organized by option, then by scenario
- Files: `processed_recording_{timestamp}.glb`

### `records/records_csv/{option_id}/{scenario_id}/`
- Contains **raw recording data** (JSON or CSV format)
- Same hierarchical structure as records_glb
- Files: `raw_recording_{timestamp}.json`

### `others/`
- Contains **project-level files** not tied to specific options/scenarios
- **Context models**: `context_{timestamp}.glb` - Base environment models
- **Heatmap models**: `heatmap_{timestamp}.glb` - Aggregated visualization data

## Implementation Details

### Client-Side Path Generation
The upload structure is managed by the client-side code in `src/lib/uploadPipeline.ts`:

```typescript
function generateStoragePath(
  entityType: EntityType,
  entityId: string,
  fileType: FileType,
  context: StorageContext
): { bucket: string; path: string }
```

### Required Context
When uploading files, you must provide:
- `projectId`: Project UUID
- `projectName`: Project name (for folder naming)
- `optionId`: Option UUID (for option and record uploads)
- `scenarioId`: Scenario UUID (for record uploads)

### Example Usage

```typescript
// Upload option model
await uploadWithPipeline(
  'option',
  optionId,
  [{ file, fileType: 'model', isRequired: true }],
  {
    projectId: 'abc-123',
    projectName: 'spatial_analysis',
    optionId: 'def-456'
  }
)
// Result: projects/spatial_analysis_abc-123/options/def-456/model_1234567890.glb

// Upload record
await uploadWithPipeline(
  'record',
  recordId,
  [
    { file: glbFile, fileType: 'processed_recording', isRequired: true },
    { file: jsonFile, fileType: 'raw_recording', isRequired: false }
  ],
  {
    projectId: 'abc-123',
    projectName: 'spatial_analysis',
    optionId: 'def-456',
    scenarioId: 'ghi-789'
  }
)
// Results:
// - projects/spatial_analysis_abc-123/records/records_glb/def-456/ghi-789/processed_recording_1234567890.glb
// - projects/spatial_analysis_abc-123/records/records_csv/def-456/ghi-789/raw_recording_1234567890.json
```

## Benefits

1. **Organization**: All project files in one place
2. **Readability**: Folder names include project names
3. **Scalability**: Clear hierarchy prevents file collisions
4. **Flexibility**: Easy to download entire projects or specific sections
5. **Debugging**: Easy to locate files in storage browser

## Migration Notes

### Old Structure (deprecated)
```
models/
  options/{option_id}/model.glb
  projects/{project_id}/context.glb

recordings/
  records/{record_id}/processed_recording.glb
```

### New Structure
Everything consolidated under `projects/{project_name}_{project_id}/`

### Breaking Changes
- All existing code calling `uploadWithPipeline()` must now pass a `StorageContext` parameter
- Storage bucket changed from `models` and `recordings` to unified `projects` bucket
- File paths now include project name and full hierarchy
