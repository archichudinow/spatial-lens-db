/**
 * Storage Path Utilities
 * 
 * Client-side utilities for working with the hierarchical storage structure.
 * These match the server-side database functions but can be used for path preview,
 * validation, or client-side operations.
 */

export type EntityType = 'option' | 'record' | 'project' | 'context' | 'heatmap'
export type FileType = 
  | 'model' 
  | 'processed_recording' 
  | 'raw_recording' 
  | 'context' 
  | 'heatmap'

export interface StorageContext {
  projectId: string
  projectName: string
  optionId?: string
  scenarioId?: string
}

export interface FileUpload {
  file: File
  fileType: FileType
  isRequired: boolean
}

/**
 * Sanitize a name for filesystem use
 * Converts to lowercase, replaces non-alphanumeric with underscore
 */
export function sanitizeName(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '') // Remove leading/trailing underscores
}

/**
 * Generate project storage path prefix
 * Format: {sanitized_project_name}_{project_id}
 */
export function getProjectStoragePath(projectName: string, projectId: string): string {
  const sanitized = sanitizeName(projectName)
  return `${sanitized}_${projectId}`
}

/**
 * Generate option model path
 * Format: {project}/options/{option_id}/model_{timestamp}.glb
 */
export function generateOptionModelPath(
  context: StorageContext,
  timestamp: number = Date.now()
): string {
  if (!context.optionId) {
    throw new Error('optionId is required for option model path')
  }
  
  const projectPath = getProjectStoragePath(context.projectName, context.projectId)
  return `${projectPath}/options/${context.optionId}/model_${timestamp}.glb`
}

/**
 * Generate record GLB path
 * Format: {project}/records/records_glb/{option_id}/{scenario_id}/processed_recording_{timestamp}.glb
 */
export function generateRecordGlbPath(
  context: StorageContext,
  timestamp: number = Date.now()
): string {
  if (!context.optionId || !context.scenarioId) {
    throw new Error('optionId and scenarioId are required for record GLB path')
  }
  
  const projectPath = getProjectStoragePath(context.projectName, context.projectId)
  return `${projectPath}/records/records_glb/${context.optionId}/${context.scenarioId}/processed_recording_${timestamp}.glb`
}

/**
 * Generate record raw data path
 * Format: {project}/records/records_csv/{option_id}/{scenario_id}/raw_recording_{timestamp}.{extension}
 */
export function generateRecordRawPath(
  context: StorageContext,
  extension: 'json' | 'csv' = 'json',
  timestamp: number = Date.now()
): string {
  if (!context.optionId || !context.scenarioId) {
    throw new Error('optionId and scenarioId are required for record raw path')
  }
  
  const projectPath = getProjectStoragePath(context.projectName, context.projectId)
  return `${projectPath}/records/records_csv/${context.optionId}/${context.scenarioId}/raw_recording_${timestamp}.${extension}`
}

/**
 * Generate project-level file path (context, heatmap, etc.)
 * Format: {project}/others/{type}_{timestamp}.glb
 */
export function generateProjectOtherPath(
  context: StorageContext,
  fileType: 'context' | 'heatmap',
  timestamp: number = Date.now()
): string {
  const projectPath = getProjectStoragePath(context.projectName, context.projectId)
  return `${projectPath}/others/${fileType}_${timestamp}.glb`
}

/**
 * Main function to generate storage path based on entity type and file type
 */
export function generateStoragePath(
  entityType: EntityType,
  fileType: FileType,
  context: StorageContext,
  timestamp: number = Date.now()
): { bucket: string; path: string } {
  const bucket = 'projects'
  
  let path: string
  
  switch (entityType) {
    case 'option':
      if (fileType !== 'model') {
        throw new Error('Option entities only support model file type')
      }
      path = generateOptionModelPath(context, timestamp)
      break
      
    case 'record':
      if (fileType === 'processed_recording') {
        path = generateRecordGlbPath(context, timestamp)
      } else if (fileType === 'raw_recording') {
        // Determine extension from file if available, default to json
        path = generateRecordRawPath(context, 'json', timestamp)
      } else {
        throw new Error('Record entities support processed_recording or raw_recording file types')
      }
      break
      
    case 'context':
      path = generateProjectOtherPath(context, 'context', timestamp)
      break
      
    case 'heatmap':
      path = generateProjectOtherPath(context, 'heatmap', timestamp)
      break
      
    default:
      throw new Error(`Unknown entity type: ${entityType}`)
  }
  
  return { bucket, path }
}

/**
 * Parse a storage path to extract its components
 */
export function parseStoragePath(path: string): {
  projectName: string
  projectId: string
  category?: 'options' | 'records' | 'others'
  optionId?: string
  scenarioId?: string
  fileType?: string
  timestamp?: number
} | null {
  // Pattern: {project_name}_{project_id}/...
  const projectMatch = path.match(/^([^_]+)_([^/]+)\/(.+)$/)
  if (!projectMatch) return null
  
  const [, projectName, projectId, rest] = projectMatch
  const result = { projectName, projectId }
  
  // Parse category
  if (rest.startsWith('options/')) {
    const optionMatch = rest.match(/^options\/([^/]+)\/([^_]+)_(\d+)\.glb$/)
    if (optionMatch) {
      return {
        ...result,
        category: 'options',
        optionId: optionMatch[1],
        fileType: optionMatch[2],
        timestamp: parseInt(optionMatch[3])
      }
    }
  } else if (rest.startsWith('records/')) {
    const recordMatch = rest.match(/^records\/(records_(?:glb|csv))\/([^/]+)\/([^/]+)\/([^_]+)_(\d+)\.(\w+)$/)
    if (recordMatch) {
      return {
        ...result,
        category: 'records',
        optionId: recordMatch[2],
        scenarioId: recordMatch[3],
        fileType: recordMatch[4],
        timestamp: parseInt(recordMatch[5])
      }
    }
  } else if (rest.startsWith('others/')) {
    const otherMatch = rest.match(/^others\/([^_]+)_(\d+)\.glb$/)
    if (otherMatch) {
      return {
        ...result,
        category: 'others',
        fileType: otherMatch[1],
        timestamp: parseInt(otherMatch[2])
      }
    }
  }
  
  return result
}

/**
 * Example usage documentation
 */
export const USAGE_EXAMPLES = {
  option: `
// Upload option model
const context = {
  projectId: 'abc-123',
  projectName: 'Spatial Analysis',
  optionId: 'def-456'
}
const { bucket, path } = generateStoragePath('option', 'model', context)
// Result: bucket='projects', path='spatial_analysis_abc-123/options/def-456/model_1234567890.glb'
`,
  
  record: `
// Upload recording
const context = {
  projectId: 'abc-123',
  projectName: 'Spatial Analysis',
  optionId: 'def-456',
  scenarioId: 'ghi-789'
}
const glbPath = generateStoragePath('record', 'processed_recording', context)
const rawPath = generateStoragePath('record', 'raw_recording', context)
// Results:
// glbPath: 'spatial_analysis_abc-123/records/records_glb/def-456/ghi-789/processed_recording_1234567890.glb'
// rawPath: 'spatial_analysis_abc-123/records/records_csv/def-456/ghi-789/raw_recording_1234567890.json'
`,
  
  project: `
// Upload project-level files
const context = {
  projectId: 'abc-123',
  projectName: 'Spatial Analysis'
}
const contextPath = generateStoragePath('context', 'context', context)
const heatmapPath = generateStoragePath('heatmap', 'heatmap', context)
// Results:
// contextPath: 'spatial_analysis_abc-123/others/context_1234567890.glb'
// heatmapPath: 'spatial_analysis_abc-123/others/heatmap_1234567890.glb'
`
}
