---
description: Trace Ember Data adapter/serializer/model relationships for debugging
allowed-tools: Read, Glob, Grep, Bash
---

# Percy Ember Data Debug

Trace the full data flow for an Ember Data resource to help debug loading issues, missing includes, and relationship errors.

## Instructions

1. Determine the target resource:
   - The user should provide a model name (e.g., "build", "project", "snapshot")
   - If not provided, ask for one

2. Trace the full data path:

   **Model** (`app/models/{resource}.js`):
   - List all `attr()` declarations
   - List all `belongsTo()` and `hasMany()` relationships with async settings
   - Note any custom transforms

   **Adapter** (`app/adapters/{resource}.js` or default):
   - Identify namespace and host
   - Note any custom URL methods (`urlForFindRecord`, etc.)
   - Note any custom headers or request modifications

   **Serializer** (`app/serializers/{resource}.js` or default):
   - List `attrs` mappings
   - Note any custom normalize/serialize methods

   **Routes** (grep for `store.findRecord('{resource}'` and `store.query('{resource}'`):
   - List all routes that load this resource
   - For each, note the `include` parameter
   - Check if all relationships accessed in the route's template are included

   **API Serializer** (`percy-api/app/serializers/{resource}_serializer.rb`):
   - List attributes and relationships exposed
   - Cross-reference with the Ember model

3. Produce a resource map:

```
## Resource: {name}

### Data Flow
Route → store.findRecord('{name}', id, {include: '...'}) → Adapter → API → Serializer → Model

### Model Attributes
| Attribute | Type | API Serializer Match |
|-----------|------|---------------------|

### Relationships
| Name | Type | Async | Included In Routes | API Serializer Match |
|------|------|-------|--------------------|---------------------|

### Routes Loading This Resource
| Route | Method | Include Params | Relationships Accessed |
|-------|--------|---------------|----------------------|

### Potential Issues
- (list any missing includes, mismatches, or async/sync concerns)
```
