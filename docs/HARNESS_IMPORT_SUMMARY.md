# Harness Git Experience Import Methods - Quick Reference

**Last Updated:** 2025-10-18

---

## Can You Bulk Import Entities?

**NO** - Harness does not support bulk import of multiple entities in a single operation.

You must import entities **one-by-one** using the UI.

---

## Import Methods Comparison

| Method | Requires Admin Access | Automatic Sync | Setup Time (3 entities) |
|--------|----------------------|----------------|------------------------|
| **Autocreation (Webhook)** | ✅ Yes | ✅ Yes | 2 minutes |
| **Manual Import** | ❌ No | ❌ No (manual reload) | 20-25 minutes |

---

## For Users WITHOUT Admin Access (Your Situation)

### Solution: Manual Import + Reload from Git

**Process:**
1. Create `.harness/` directory structure in Git
2. Push YAML files to main branch
3. Import each entity via Harness UI:
   - Pipelines → New Pipeline → Import From Git
   - Templates → New Template → Import From Git
   - Input Sets → New Input Set → Import From Git
4. For future changes:
   - Edit YAML in Git → Push to main
   - Click "Reload from Git" button in Harness UI

**Time Required:**
- Initial import: 20-25 minutes (3 entities)
- Future updates: 2-3 minutes per entity (manual reload)

---

## For Users WITH Admin Access

### Solution: Autocreation (Recommended)

**Process:**
1. Register project-level webhook in Harness
2. Create `.harness/` directory structure
3. Push to main branch
4. Entities automatically created (30-60 seconds)

**Time Required:**
- Initial setup: 2 minutes
- Future updates: Automatic (30-60 seconds after push)

---

## Manual Import Steps (Detailed)

### Import Pipeline
1. Harness UI → Pipelines → New Pipeline → Remote
2. Click "Import From Git"
3. Configure:
   - Git Connector: `github_bagel_store`
   - Repository: `harness-gha-bagelstore`
   - Branch: `main`
   - YAML Path: `.harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store.yaml`
4. Click "Import"

### Import Template
1. Harness UI → Templates → New Template
2. Click "Import From Git"
3. Configure:
   - Same Git settings as above
   - YAML Path: `.harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment/v1_0.yaml`
4. Click "Import"

### Import Input Set
1. Harness UI → Pipelines → Deploy Bagel Store → Input Sets
2. Click "New Input Set" → "Import From Git"
3. Configure:
   - Same Git settings as above
   - YAML Path: `.harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store/input_sets/webhook_default.yaml`
4. Click "Import"

---

## Key Takeaways

✅ **What Works Without Admin Access:**
- Manual import from Git (one-by-one)
- "Reload from Git" for syncing changes
- Git-backed entities (version controlled)
- Same `.harness/` directory structure as autocreation

❌ **What Doesn't Work Without Admin Access:**
- Autocreation (requires webhook)
- Automatic sync on Git push
- Bulk import of multiple entities

---

## Migration Path

**If you gain admin access later:**

Current State → Register Webhook → Autocreation Active

**Time:** 5 minutes (entities already in `.harness/` structure)

---

## Next Steps

1. **Read Full Research:** `docs/HARNESS_BULK_IMPORT_RESEARCH.md`
2. **Follow Migration Plan:** Updated plan for manual import coming soon
3. **Test Import Workflow:** Try importing one test entity first

---

**Related Documents:**
- Full Research: `docs/HARNESS_BULK_IMPORT_RESEARCH.md`
- Original Migration Plan: `docs/HARNESS_AUTOCREATION_MIGRATION.md` (webhook-based)
