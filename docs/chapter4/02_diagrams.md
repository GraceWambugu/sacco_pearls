# Analysis and design diagrams (draft for Chapter 4)

The diagrams are written in Mermaid, so they stay in step with the code and can be redrawn quickly.
To turn them into images for the report: open this file in VS Code with the "Markdown Preview Mermaid
Support" extension, or paste each block into https://mermaid.live and export PNG.

Proposal section 3.4 asks for: a use case diagram, an activity diagram (ETL), a sequence diagram
(comparison), wireframes and the database schema. An architecture diagram is added for section 3.8.

## 4.x Use case diagram

```mermaid
flowchart LR
    member(["👤 SACCO member /<br/>prospective member"])
    admin(["👤 System administrator"])
    sasra(["📄 SASRA annual report<br/>(external)"])

    subgraph System["SACCOLens"]
        UC1([Search and filter SACCOs])
        UC2([View SACCO health profile])
        UC3([Compare up to 3 SACCOs])
        UC4([View top-ranked SACCOs])
        UC5([View trends over the years])
        UC6([Register / sign in / reset password])
        UC7([Save SACCOs to a shortlist])
        UC8([Upload report and load figures])
        UC9([Correct or archive SACCO data])
        UC10([Score SACCOs with PEARLS rules])
    end

    member --- UC1 & UC2 & UC3 & UC4 & UC5 & UC6 & UC7
    admin --- UC6 & UC8 & UC9
    sasra --- UC8
    UC7 -. "&lt;&lt;include&gt;&gt;" .-> UC6
    UC2 -. "&lt;&lt;include&gt;&gt;" .-> UC10
    UC3 -. "&lt;&lt;include&gt;&gt;" .-> UC10
    UC4 -. "&lt;&lt;include&gt;&gt;" .-> UC10
```

Note for the write-up: searching, viewing, comparing and trends need no account; only saving does (UC7 includes UC6).

## 4.x Activity diagram: ETL pipeline

```mermaid
flowchart TD
    A([Start: new SASRA report published]) --> B[Admin finds the appendix pages<br/>in the report's table of contents]
    B --> C[Upload PDF with page range and data years]
    C --> D[Camelot lattice mode extracts the tables]
    D --> E{Rows extracted?}
    E -- No --> E1[Show error: check page range] --> C
    E -- Yes --> F{Table layout}
    F -- "12 columns" --> G1[Read CCA, CCD, ICA,<br/>external borrowing, NPL]
    F -- "14 columns (2022 report)" --> G2[Also read liquidity ratio]
    F -- "Growth table" --> G3[Read assets, deposits,<br/>loans, income]
    G1 & G2 & G3 --> H[Clean values: % signs, brackets as<br/>negatives, asterisk = stale flag]
    H --> I[Normalise SACCO name and match<br/>through sacco_aliases]
    I --> J{SACCO-year already stored?}
    J -- No --> K[Insert new record<br/>with report and page]
    J -- Yes --> L{Field empty?}
    L -- Yes --> M[Fill the empty field]
    L -- No --> N[Compare values and log<br/>match or mismatch; keep stored value]
    K & M & N --> O{More rows?}
    O -- Yes --> I
    O -- No --> P[Write validation log CSV]
    P --> Q([End: figures ready for scoring])
```

## 4.x Sequence diagram: comparing SACCOs

```mermaid
sequenceDiagram
    actor M as Member
    participant App as Flutter app<br/>(Compare tab)
    participant P as CompareProvider
    participant API as FastAPI backend<br/>GET /compare
    participant S as Scoring engine<br/>(scoring.py)
    participant DB as PostgreSQL

    M->>App: Tap "Add to compare" on two SACCOs
    App->>P: add(sacco)
    P-->>App: notify listeners (badge shows 2)
    M->>App: Open Compare tab
    App->>API: GET /compare?ids=4,5
    API->>DB: SELECT SACCOs and the years each has figures
    DB-->>API: rows
    API->>API: choose the latest year all have
    API->>DB: SELECT figures for that year and the year before; peer incomes
    DB-->>API: financial_metrics rows
    loop for each SACCO
        API->>S: score_sacco(metric, prior, peer median, inflation)
        S-->>API: dimensions, composite, rating, overrides, flags
    end
    API-->>App: 200 {year, results, ranking}
    App->>App: rank (ties are joint), draw radar and table
    App-->>M: Side-by-side comparison
    alt server unreachable
        API--xApp: no response
        App-->>M: "Could not reach the server" + Try again
    end
```

## 4.x Database schema (ERD)

```mermaid
erDiagram
    USERS ||--o{ WATCHLISTS : owns
    USERS ||--o{ PASSWORD_RESET_TOKENS : requests
    WATCHLISTS ||--o{ WATCHLIST_ITEMS : contains
    SACCOS ||--o{ WATCHLIST_ITEMS : "is saved in"
    SACCOS ||--o{ SACCO_ALIASES : "is known as"
    SACCOS ||--o{ FINANCIAL_METRICS : reports
    REPORTS ||--o{ FINANCIAL_METRICS : "is source of"
    SACCOS ||--o{ PEARLS_SCORES : "(reserved)"

    USERS {
        int id PK
        string email UK
        string password_hash "Argon2id"
        string full_name
        string role "member | admin"
        bool is_active
    }
    PASSWORD_RESET_TOKENS {
        int id PK
        int user_id FK
        string token_hash UK "SHA-256"
        datetime expires_at
        datetime consumed_at
    }
    SACCOS {
        int id PK
        string name UK
        string county
        bool is_archived
    }
    SACCO_ALIASES {
        int id PK
        int sacco_id FK
        string alias UK "normalised name"
    }
    REPORTS {
        int id PK
        int report_year UK
        string source_file
        string units
    }
    FINANCIAL_METRICS {
        int id PK
        int sacco_id FK
        int data_year "unique with sacco_id"
        float total_assets "KES bn"
        float total_deposits
        float gross_loans
        float total_income
        float cca "core capital / assets %"
        float ccd "core capital / deposits %"
        float ica "institutional capital / assets %"
        float ext_borrowing "% of assets"
        float npl_ratio "%"
        float liquidity_ratio "% (2021-2022 only)"
        bool data_stale "asterisk in SASRA table"
        int report_id FK
        int source_page
    }
    WATCHLISTS {
        int id PK
        int user_id FK
        string name "unique per user"
    }
    WATCHLIST_ITEMS {
        int watchlist_id PK, FK
        int sacco_id PK, FK
    }
    PEARLS_SCORES {
        int id PK
        int sacco_id FK
        int data_year
        float composite_score
        string rating
    }
```

Every table also has `created_at` and `updated_at`. An `audit_logs` table records admin changes
(entity, action, actor, before and after values). `pearls_scores` is kept for a future cache; scores
are currently computed on request so they always follow the current rules.

## 4.x System architecture (three-tier)

```mermaid
flowchart LR
    subgraph Presentation["Presentation tier"]
        APP["Flutter app (Android / iOS)<br/>dio · provider · fl_chart"]
        ADMIN["Admin web panel<br/>(admin.html)"]
    end
    subgraph Logic["Logic tier: FastAPI (Python 3.11)"]
        AUTH["Auth: Argon2id + JWT"]
        API["REST endpoints<br/>/saccos /score /compare /rankings /trend"]
        SCORE["Scoring engine<br/>scoring.py (rules)"]
        ETL["ETL: Camelot + pandas<br/>etl.py, loader scripts"]
    end
    subgraph Data["Data tier"]
        PG[("PostgreSQL<br/>sacco_db")]
    end
    PDF["SASRA PDF reports<br/>2020-2024"] --> ETL
    APP -- "HTTPS / JSON" --> API
    ADMIN -- "HTTPS / JSON + PDF upload" --> API
    API --> AUTH
    API --> SCORE
    API --> PG
    ETL --> PG
```

## 4.x Wireframes

Screenshots of the working prototype are in `docs/chapter4/screens/` (taken from the Android
emulator). Use them as the screen-by-screen reference the proposal asks for, with one line under
each saying what the member can do there.
