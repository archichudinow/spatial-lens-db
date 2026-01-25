# Storage Structure Visualization

## Directory Tree

```
📦 projects (bucket)
│
├── 📁 spatial_analysis_abc-123-def/
│   │
│   ├── 📁 options/
│   │   ├── 📁 option-uuid-001/
│   │   │   ├── 📄 model_1706180000000.glb
│   │   │   └── 📄 model_1706180050000.glb
│   │   │
│   │   └── 📁 option-uuid-002/
│   │       └── 📄 model_1706180100000.glb
│   │
│   ├── 📁 records/
│   │   │
│   │   ├── 📁 records_glb/
│   │   │   ├── 📁 option-uuid-001/
│   │   │   │   ├── 📁 scenario-uuid-001/
│   │   │   │   │   ├── 📄 processed_recording_1706180200000.glb
│   │   │   │   │   └── 📄 processed_recording_1706180300000.glb
│   │   │   │   │
│   │   │   │   └── 📁 scenario-uuid-002/
│   │   │   │       └── 📄 processed_recording_1706180400000.glb
│   │   │   │
│   │   │   └── 📁 option-uuid-002/
│   │   │       └── 📁 scenario-uuid-001/
│   │   │           └── 📄 processed_recording_1706180500000.glb
│   │   │
│   │   └── 📁 records_csv/
│   │       ├── 📁 option-uuid-001/
│   │       │   ├── 📁 scenario-uuid-001/
│   │       │   │   ├── 📄 raw_recording_1706180200000.json
│   │       │   │   └── 📄 raw_recording_1706180300000.csv
│   │       │   │
│   │       │   └── 📁 scenario-uuid-002/
│   │       │       └── 📄 raw_recording_1706180400000.json
│   │       │
│   │       └── 📁 option-uuid-002/
│   │           └── 📁 scenario-uuid-001/
│   │               └── 📄 raw_recording_1706180500000.json
│   │
│   └── 📁 others/
│       ├── 📄 context_1706180000000.glb
│       ├── 📄 context_1706180100000.glb
│       └── 📄 heatmap_1706180200000.glb
│
└── 📁 urban_planning_xyz-789-hij/
    ├── 📁 options/
    │   └── 📁 option-uuid-003/
    │       └── 📄 model_1706180600000.glb
    │
    ├── 📁 records/
    │   ├── 📁 records_glb/
    │   │   └── ...
    │   └── 📁 records_csv/
    │       └── ...
    │
    └── 📁 others/
        └── 📄 context_1706180700000.glb
```

## Data Flow Diagram

```
┌──────────────┐
│   Client     │
│ Application  │
└──────┬───────┘
       │
       │ 1. FormData Upload
       │    (projectId, optionId, scenarioId, files)
       ▼
┌──────────────────────────────────────────┐
│         Edge Function                     │
│  (save-recording-with-glb)               │
│                                          │
│  ┌────────────────────────────────┐    │
│  │  2. Get Project Storage Path   │    │
│  │  RPC: get_project_storage_path │    │
│  │  Returns: "project_name_id"    │    │
│  └────────────────────────────────┘    │
│                                          │
│  ┌────────────────────────────────┐    │
│  │  3. Generate File Paths        │    │
│  │  RPC: generate_record_glb_path │    │
│  │  RPC: generate_record_raw_path │    │
│  └────────────────────────────────┘    │
│                                          │
│  ┌────────────────────────────────┐    │
│  │  4. Upload to Storage          │    │
│  │  Bucket: projects              │    │
│  │  Path: hierarchical structure  │    │
│  └────────────────────────────────┘    │
│                                          │
│  ┌────────────────────────────────┐    │
│  │  5. Create DB Record           │    │
│  │  Table: records                │    │
│  │  Columns: URLs, metadata       │    │
│  └────────────────────────────────┘    │
└──────────┬───────────────────────────────┘
           │
           │ 6. Success Response
           │    { record, glbUrl, rawUrl }
           ▼
┌──────────────┐
│   Client     │
│ Application  │
└──────────────┘
```

## Path Generation Flow

```
Input Parameters
─────────────────
projectId:   "abc-123-def"
projectName: "Spatial Analysis"
optionId:    "opt-456"
scenarioId:  "scn-789"
timestamp:   1706180000000

         │
         ▼
┌────────────────────────────┐
│  Sanitize Project Name     │
│  "Spatial Analysis"        │
│         ↓                  │
│  "spatial_analysis"        │
└────────────────────────────┘
         │
         ▼
┌────────────────────────────┐
│  Combine with Project ID   │
│  "spatial_analysis" +      │
│  "_" + "abc-123-def"       │
│         ↓                  │
│  "spatial_analysis_abc-123"│
└────────────────────────────┘
         │
         ▼
┌────────────────────────────┐
│  Build Hierarchical Path   │
│                            │
│  For Record GLB:           │
│  {project}/                │
│    records/                │
│      records_glb/          │
│        {optionId}/         │
│          {scenarioId}/     │
│            processed_      │
│            recording_      │
│            {timestamp}.glb │
└────────────────────────────┘
         │
         ▼
Final Path
──────────────────────────────
spatial_analysis_abc-123/
  records/
    records_glb/
      opt-456/
        scn-789/
          processed_recording_1706180000000.glb
```

## Database Function Chain

```sql
-- 1. Get Project Storage Path
SELECT get_project_storage_path('abc-123')
  ↓
  Queries: projects.name WHERE id = 'abc-123'
  ↓
  Sanitizes: 'Spatial Analysis' → 'spatial_analysis'
  ↓
  Returns: 'spatial_analysis_abc-123'

-- 2. Generate Record GLB Path
SELECT generate_record_glb_path(
  'abc-123',   -- project_id
  'opt-456',   -- option_id
  'scn-789',   -- scenario_id
  1706180000   -- timestamp
)
  ↓
  Calls: get_project_storage_path('abc-123')
  ↓
  Builds: '{project_path}/records/records_glb/{opt}/{scn}/processed_recording_{ts}.glb'
  ↓
  Returns: 'spatial_analysis_abc-123/records/records_glb/opt-456/scn-789/processed_recording_1706180000.glb'
```

## Security Model

```
┌─────────────────────────────────────────────┐
│           Storage Bucket: projects           │
│                  (public)                    │
└─────────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
    READ (✅)              WRITE (❌/✅)
        │                       │
  ┌─────┴─────┐         ┌──────┴──────┐
  │   Anyone  │         │ service_role│
  │  (public) │         │    ONLY     │
  └───────────┘         └─────────────┘
      │                       │
      ▼                       ▼
  Direct URL          Edge Functions
   Download              Upload
                       Update
                       Delete

Access Control:
───────────────
• Public/Anon:  READ ONLY (SELECT)
• Authenticated: READ ONLY (SELECT)
• Service Role: FULL ACCESS (INSERT/UPDATE/DELETE)

Enforcement:
────────────
RLS Policies on storage.objects:
✅ public_read_projects_bucket (SELECT for public)
✅ authenticated_read_projects_bucket (SELECT for authenticated)
✅ service_role_insert_projects_bucket (INSERT for service_role)
✅ service_role_update_projects_bucket (UPDATE for service_role)
✅ service_role_delete_projects_bucket (DELETE for service_role)
```

## File Naming Convention

```
Pattern: {type}_{timestamp}.{extension}

Examples:
─────────
model_1706180000000.glb
processed_recording_1706180000000.glb
raw_recording_1706180000000.json
context_1706180000000.glb
heatmap_1706180000000.glb

Timestamp: Unix epoch milliseconds
Benefits:
  • Chronological sorting
  • Unique filenames
  • No name collisions
  • Easy to parse
```

## Benefits Summary

```
┌─────────────────────────────────────────────────┐
│               OLD STRUCTURE                      │
│  models/                                        │
│    options/{id}/model.glb     ❌ Flat          │
│  recordings/                                     │
│    records/{id}/recording.glb ❌ No hierarchy  │
└─────────────────────────────────────────────────┘
                    │
                    ▼ MIGRATION
┌─────────────────────────────────────────────────┐
│               NEW STRUCTURE                      │
│  projects/                                       │
│    {name}_{id}/               ✅ Readable      │
│      options/{opt}/           ✅ Hierarchical  │
│      records/                 ✅ Organized     │
│        records_glb/           ✅ Scalable      │
│        records_csv/           ✅ Debuggable    │
│      others/                  ✅ Flexible      │
└─────────────────────────────────────────────────┘

Improvements:
──────────────
✅ All project files in one place
✅ Human-readable folder names
✅ Clear hierarchy prevents collisions
✅ Easy to download entire projects
✅ Simple to navigate in storage browser
✅ Database-driven path consistency
✅ Centralized security enforcement
```
