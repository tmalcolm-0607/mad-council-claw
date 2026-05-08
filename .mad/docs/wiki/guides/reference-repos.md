# Reference Repos

All the ecosystem repos are available locally for cross-repo analysis, pattern extraction, and audits:

```
references/
  DARS-CMS Object and Properties/   # DARS domain model reference
  a data-collection service/                          # Data Collection Service
  a delivery service/                     # Delivery Service
  an internal docs repo/                         # Documentation
  another ecosystem service/                      # Exchange Service
  a gateway API service/                        # Law Enforcement API
  a portal service/                     # Law Enforcement Portal
  a frontend project/                         # Legal Request Management Service
  a publish service/                      # Publish Service
  a shared service/                          # Subscription Management Service (primary CMS reference)
  another consumer service/                        # Teams Integration Service
  another-service/                   # e.g. a sibling platform/evidence service
```

**CRITICAL**: Always check `references/` for cross-repo patterns before claiming a pattern doesn't exist in the the ecosystem. These repos are the authoritative source for the ecosystem conventions.
