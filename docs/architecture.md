# SATYA Architecture

## System Overview

```mermaid
graph TB
    subgraph External["External Systems"]
        ES[eSAKSHI Portal]
        BH[Bhuvan WMS]
        FCM[Firebase Cloud Messaging]
    end

    subgraph Mobile["Flutter Mobile App"]
        OFF[Offline Store]
        CAM[Camera + AR]
        GPS[GPS + Location]
        SYNC[Sync Engine]
    end

    subgraph Backend["FastAPI Backend"]
        direction TB
        AUTH[Auth Service<br/>OTP + JWT]
        API[API Layer<br/>40 endpoints]
        RISK[Risk Engine<br/>33 rules]
        EVP[Evidence Pipeline<br/>EXIF → pHash → blur]
        SAT[Satellite Adapter<br/>Fixture / Bhuvan]
        AUD[Audit Chain<br/>SHA-256]
    end

    subgraph Data["PostgreSQL 16 + PostGIS"]
        W[(Works)]
        E[(Evidence)]
        RA[(Risk Assessments)]
        AL[(Audit Log)]
    end

    subgraph Storage["Cloudflare R2"]
        PHO[Photos<br/>Face-blurred]
    end

    Mobile <-->|JWT + JSON| Backend
    Backend --> Data
    Backend --> Storage
    SAT -.->|WMS GetMap| BH
    EVP -.->|eSAKSHI ref| ES
    Backend -.->|Push| FCM
```

## Request Flow

```mermaid
sequenceDiagram
    participant M as Mobile
    participant A as API
    participant R as Risk Engine
    participant D as Database

    M->>A: POST /evidence (photo)
    A->>A: Extract EXIF + GPS
    A->>A: Compute pHash (64-bit DCT)
    A->>A: Blur faces (OpenCV)
    A->>D: Store evidence row
    A->>R: score_work(work)
    R->>D: build_facts() — benchmark, z-score, IForest, geo-dup, photo reuse
    R->>R: assess(facts) — 33 rules, additive scoring
    R->>D: Persist assessment + reasons + source verdicts
    R-->>A: AssessmentResult
    A-->>M: Score 78, band RED, 5 reasons
```

## Scoring Flow

```mermaid
flowchart TD
    F[facts dict] --> E{Evaluate 33 rules<br/>simpleeval}
    E --> |fired| CAP[Per-category cap]
    CAP --> TOT[Total cap at 100]
    TOT --> HAM[Hamilton apportionment]
    HAM --> S[Score + Reasons<br/>sum = score exactly]
    S --> B{Band}
    B --> G[0-30 GREEN]
    B --> Y[31-70 YELLOW]
    B --> R[71-100 RED]
```

## Offline Sync Model

```mermaid
sequenceDiagram
    participant P as Phone
    participant S as Server

    Note over P: Offline — collect evidence, measurements, reports

    P->>S: POST /sync/push [{op1, client_uuid}, {op2, client_uuid}]
    S->>S: For each op: savepoint → try insert → on conflict return stored result
    S-->>P: [{applied, server_id}, {duplicate, server_id}]

    P->>S: GET /sync/pull?cursor=42
    S-->>P: {items: [...changed rows...], next_cursor: 57}

    Note over P,S: Append-only events can't conflict.<br/>Decisions are online-only.
```

## Deployment

```mermaid
graph LR
    GH[GitHub] -->|push| R[Render]
    R -->|pre-deploy| ALB[alembic upgrade head]
    ALB --> APP[uvicorn · 2 workers]
    APP --> NEON[(Neon PostgreSQL<br/>PostGIS · Free)]
    APP --> R2[(Cloudflare R2<br/>Photos · Free)]
    APP --> HZ[/healthz]
    APP --> RZ[/readyz]
```

| Component | Service | Cost | Why |
|-----------|---------|------|-----|
| API | Render Starter | $7/mo | No cold start (free tier = 50s) |
| Database | Neon Free | $0 | PostGIS, never expires, 0.5 GB |
| Photos | R2 Free | $0 | 10 GB, zero egress |
| Push | FCM | $0 | Free tier covers demo volume |
