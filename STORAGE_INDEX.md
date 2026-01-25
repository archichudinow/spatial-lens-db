# Storage Update - Documentation Index

This directory contains all documentation for the hierarchical storage structure implementation.

## 📚 Documentation Files

### Quick Start
- **[STORAGE_QUICK_REFERENCE.md](STORAGE_QUICK_REFERENCE.md)** - Quick reference card for developers (⭐ Start here!)
- **[STORAGE_VISUALIZATION.md](STORAGE_VISUALIZATION.md)** - Visual diagrams and examples

### Design & Implementation
- **[STORAGE_UPDATE.md](STORAGE_UPDATE.md)** - Original design specification (target structure)
- **[STORAGE_IMPLEMENTATION.md](STORAGE_IMPLEMENTATION.md)** - Complete implementation guide
- **[STORAGE_IMPLEMENTATION_SUMMARY.md](STORAGE_IMPLEMENTATION_SUMMARY.md)** - Implementation summary

### Operations
- **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** - Step-by-step deployment guide

## 🎯 Reading Guide

### For Developers
1. Start with [STORAGE_QUICK_REFERENCE.md](STORAGE_QUICK_REFERENCE.md)
2. Review [STORAGE_VISUALIZATION.md](STORAGE_VISUALIZATION.md) for visual understanding
3. Reference [STORAGE_IMPLEMENTATION.md](STORAGE_IMPLEMENTATION.md) for detailed usage

### For DevOps/Deployment
1. Read [STORAGE_IMPLEMENTATION_SUMMARY.md](STORAGE_IMPLEMENTATION_SUMMARY.md) for overview
2. Follow [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) step-by-step
3. Reference [STORAGE_IMPLEMENTATION.md](STORAGE_IMPLEMENTATION.md) for troubleshooting

### For System Design
1. Start with [STORAGE_UPDATE.md](STORAGE_UPDATE.md) for design rationale
2. Review [STORAGE_VISUALIZATION.md](STORAGE_VISUALIZATION.md) for architecture
3. Read [STORAGE_IMPLEMENTATION.md](STORAGE_IMPLEMENTATION.md) for technical details

## 📁 File Structure

```
spatial-lens-db/
│
├── Documentation (this section)
│   ├── STORAGE_UPDATE.md                    # Design spec
│   ├── STORAGE_IMPLEMENTATION.md            # Implementation guide
│   ├── STORAGE_IMPLEMENTATION_SUMMARY.md    # Summary
│   ├── STORAGE_QUICK_REFERENCE.md          # Quick ref
│   ├── STORAGE_VISUALIZATION.md             # Diagrams
│   ├── DEPLOYMENT_CHECKLIST.md              # Deployment
│   └── STORAGE_INDEX.md                     # This file
│
├── Database Migrations
│   ├── 20260125161000_add_project_name_field.sql
│   └── 20260125162000_consolidate_storage_buckets.sql
│
├── Edge Functions
│   ├── save-recording/index.ts
│   └── save-recording-with-glb/index.ts
│
└── Client Utilities
    └── supabase/storage-utils.ts
```

## 🚀 Implementation Checklist

### ✅ Completed
- [x] Database schema for project names
- [x] Storage path generation functions
- [x] Unified `projects` bucket
- [x] Storage policies (service_role only)
- [x] Updated edge functions
- [x] Client TypeScript utilities
- [x] Complete documentation

### 📋 Pending (Deployment)
- [ ] Local testing
- [ ] Staging deployment
- [ ] Production deployment
- [ ] Client app integration
- [ ] Data migration (if needed)

## 📖 Key Concepts

### Hierarchical Structure
```
projects/{project_name}_{project_id}/
  ├── options/{option_id}/model_*.glb
  ├── records/
  │   ├── records_glb/{option_id}/{scenario_id}/processed_recording_*.glb
  │   └── records_csv/{option_id}/{scenario_id}/raw_recording_*.{json|csv}
  └── others/
      ├── context_*.glb
      └── heatmap_*.glb
```

### Database Functions
- `get_project_storage_path(project_id)` - Generate project folder name
- `generate_option_model_path(...)` - Option model paths
- `generate_record_glb_path(...)` - Recording GLB paths
- `generate_record_raw_path(...)` - Recording raw data paths
- `generate_project_other_path(...)` - Context/heatmap paths

### Security Model
- Public: **Read only**
- Service Role: **Full access**
- All uploads: **Via Edge Functions**

## 🔗 External Resources

- [Supabase Storage Documentation](https://supabase.com/docs/guides/storage)
- [Edge Functions Documentation](https://supabase.com/docs/guides/functions)
- [PostgreSQL Functions](https://www.postgresql.org/docs/current/sql-createfunction.html)

## 💡 Tips

### Finding Information Quickly
- **Path examples**: See [STORAGE_QUICK_REFERENCE.md](STORAGE_QUICK_REFERENCE.md#path-patterns)
- **Visual structure**: See [STORAGE_VISUALIZATION.md](STORAGE_VISUALIZATION.md#directory-tree)
- **Code examples**: See [STORAGE_IMPLEMENTATION.md](STORAGE_IMPLEMENTATION.md#how-to-use)
- **Deployment steps**: See [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)

### Common Tasks
| Task | Document | Section |
|------|----------|---------|
| Generate path | STORAGE_QUICK_REFERENCE.md | Database Functions |
| Upload file | STORAGE_QUICK_REFERENCE.md | Edge Function Usage |
| Parse path | STORAGE_QUICK_REFERENCE.md | Client TypeScript Usage |
| Deploy | DEPLOYMENT_CHECKLIST.md | All sections |
| Troubleshoot | STORAGE_IMPLEMENTATION.md | Troubleshooting |

## 📞 Support

For questions or issues:
1. Check the relevant documentation file
2. Review [STORAGE_IMPLEMENTATION.md](STORAGE_IMPLEMENTATION.md#troubleshooting)
3. Check Edge Function logs in Supabase Dashboard
4. Review storage browser for actual file structure

## 🔄 Updates

This documentation set was created on **January 25, 2026** and reflects the current implementation.

**Last Updated**: January 25, 2026  
**Version**: 1.0.0  
**Status**: Complete, pending deployment
