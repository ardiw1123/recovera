# Graph Report - recovera  (2026-10-16)

## Corpus Check
- 203 files · ~73,373 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 20 file(s) not represented in the graph (top: (none) 7, .xml 7, .properties 2)

## Summary
- 1587 nodes · 2308 edges · 162 communities (82 shown, 80 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 138 edges (avg confidence: 0.89)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Database Schema Constants
- Test Qa
- Home Feature Models
- Local Database Service
- Data Models
- Postgres Best Practices Docs
- Backend App
- Token Storage
- Data Models
-  Claude Skills
-  Agents Skills
- Backend App
- Auth UI & Screens
- Lib Features
- Backend App
- Backend App
- Backend App
- Lib Data
- Stok Inventory Feature
- Data Repositories
- Auth UI & Screens
- Backend App
- Postgres Best Practices Docs
- Data Repositories
- Auth UI & Screens
- Core Constants
-  Claude Skills
- Backend App
- Data Models
- Test Data Layer
- Auth UI & Screens
- Lib Core Theme
- Core Networking
- Seed Buyer
- Data Repositories
- Home Feature Models
- Backend App
- Core Networking
- Lib Features Shell
- Backend App
- Backend App
- Database Schema Constants
-  Claude Skills
- Docs Recovera Database
- Auth UI & Screens
- Auth UI & Screens
- Lib Features
- Lib Features
- Backend Tests Conftest
- Lib Core Navigation
- Data Models
- Data Repositories
- Backend App
- Lib Main
-  Claude Skills
-  Claude Skills
- Backend App
- Backend App
- Lib Data
- Pubspec Flutter
-  Claude Skills
- Backend App
- Data Models
- Web Manifest
-  Claude Skills
-  Claude Skills
- Postgres Best Practices Docs
- Backend Tests Test
-  Claude Skills
- Home Feature Models
-  Claude Skills
- Postgres Best Practices Docs
-  Claude Skills
-  Claude Skills
- Postgres Best Practices Docs
- Postgres Best Practices Docs
-  Claude Skills
-  Claude Skills
-  Claude Skills
- Backend API Routes
-  Claude Skills
-  Claude Skills
-  Claude Skills
-  Claude Skills
- Docs Recovera
- Android App Src
- Docs Recovera
-  Claude Skills
- Postgres Best Practices Docs
- Postgres Best Practices Docs
- Analysis Options
- Backend Docker Compose
- Backend Readme Bot
- Backend Readme Dutch
- Backend Readme Fastapi
- Docs Recovera
- Docs Recovera
- Docs Recovera
- Docs Recovera
-  Claude Skills
-  Claude Skills
-  Claude Skills
-  Claude Skills
-  Claude Skills
-  Claude Skills
- Postgres Best Practices Docs
- Postgres Best Practices Docs
- Postgres Best Practices Docs
- Postgres Best Practices Docs
- Backend Docker Compose
- Backend Docker Compose
- Backend Docker Compose
- Backend Docker Compose
- Backend Readme Api
- Backend Readme B2B
- Backend Requirements Alembic
- Backend Requirements Bcrypt
- Backend Requirements Psycopg
- Backend Requirements Pydantic
- Backend Requirements Pyjwt
- Backend Requirements Sqlalchemy
- Backend Tech Stack
- Claude Skills Supabase
- Docs Recovera Database
- Docs Recovera Database
- Docs Recovera Database
- Docs Recovera Database
- Docs Recovera Database
- Docs Recovera Database
- Docs Recovera Database
- Docs Recovera Database
- Docs Recovera Database
- Docs Recovera Database
- Docs Recovera Prd
- Docs Recovera Prd
- Docs Recovera Prd
- Docs Recovera Prd
- Docs Recovera Prd
- Docs Recovera Prd
- Docs Recovera Prd
- Docs Recovera Prd
- Docs Recovera Product
- Docs Recovera Product
- Docs Recovera Product
- Docs Recovera Product
- Docs Recovera Product
- Docs Recovera Product
- Partial Index
- Pkg Recovera Backend
- Web Index Flutter
- Web Index Flutter

## God Nodes (most connected - your core abstractions)
1. `wrap_success()` - 42 edges
2. `AppException` - 26 edges
3. `Supabase Skill` - 25 edges
4. `Listing` - 18 edges
5. `Seller` - 15 edges
6. `update_listing()` - 15 edges
7. `ResponseEnvelope` - 15 edges
8. `create_listing()` - 14 edges
9. `register_user()` - 14 edges
10. `get_order_detail()` - 13 edges

## Surprising Connections (you probably didn't know these)
- `create_access_token()` --calls--> `JSON Web Token (JWT)`  [EXTRACTED]
  backend/app/core/security.py → .claude/skills/supabase/SKILL.md
- `decode_token()` --calls--> `JSON Web Token (JWT)`  [EXTRACTED]
  backend/app/core/security.py → .claude/skills/supabase/SKILL.md
- `extract_invoice()` --references--> `description`  [EXTRACTED]
  backend/app/routers/ai.py → web/manifest.json
- `verify_tx_hash()` --references--> `description`  [EXTRACTED]
  backend/app/routers/blockchain.py → web/manifest.json
- `get_certificate()` --references--> `description`  [EXTRACTED]
  backend/app/routers/donations.py → web/manifest.json

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **** — agents_skills_supabase_postgres_best_practices_references_conn_idle_timeout_timeout, agents_skills_supabase_postgres_best_practices_references_conn_limits_max_connections, agents_skills_supabase_postgres_best_practices_references_conn_pooling_pgbouncer, agents_skills_supabase_postgres_best_practices_references_conn_prepared_statements_prepared_statement, agents_skills_supabase_postgres_best_practices_references_sections_connection_management [INFERRED 0.85]
- **** — agents_skills_supabase_postgres_best_practices_references_query_index_types_index_type, agents_skills_supabase_postgres_best_practices_references_query_composite_indexes_composite_index, agents_skills_supabase_postgres_best_practices_references_query_covering_indexes_covering_index, agents_skills_supabase_postgres_best_practices_references_query_partial_indexes_partial_index, agents_skills_supabase_postgres_best_practices_references_query_missing_indexes_missing_index, agents_skills_supabase_postgres_best_practices_references_schema_foreign_key_indexes_foreign_key_index [INFERRED 0.80]
- **** — agents_skills_supabase_postgres_best_practices_references_monitor_explain_analyze_explain_analyze, agents_skills_supabase_postgres_best_practices_references_monitor_pg_stat_statements_pg_stat_statements, agents_skills_supabase_postgres_best_practices_references_monitor_vacuum_analyze_vacuum_analyze [INFERRED 0.80]
- **** — agents_skills_supabase_postgres_best_practices_references_security_privileges_privilege, agents_skills_supabase_postgres_best_practices_references_security_rls_basics_row_level_security, agents_skills_supabase_postgres_best_practices_references_security_rls_performance_rls_performance [INFERRED 0.85]
- **** — query_performance, connection_management, security_rls, schema_design, concurrency_locking, data_access_patterns, monitoring_diagnostics, advanced_features [INFERRED 0.90]
- **** — connection_pooling, max_connections, idle_in_transaction_session_timeout, pgbouncer [INFERRED 0.85]
- **** — advisory_lock, deadlock, lock_ordering, short_transaction [INFERRED 0.85]
- **** — _claude_skills_supabase_postgres_best_practices_references_query_composite_indexes_composite_index, _claude_skills_supabase_postgres_best_practices_references_query_covering_indexes_covering_index, _claude_skills_supabase_postgres_best_practices_references_query_index_types_btree_index, _claude_skills_supabase_postgres_best_practices_references_query_missing_indexes_missing_index, _claude_skills_supabase_postgres_best_practices_references_query_partial_indexes_partial_index, _claude_skills_supabase_postgres_best_practices_references_schema_foreign_key_indexes_foreign_key_index [INFERRED 0.75]
- **** — _claude_skills_supabase_postgres_best_practices_references_security_rls_basics_row_level_security, _claude_skills_supabase_postgres_best_practices_references_security_rls_basics_rls_policy, _claude_skills_supabase_postgres_best_practices_references_security_rls_performance_rls_policy_performance, _claude_skills_supabase_postgres_best_practices_references_security_rls_performance_index_on_rls_policy_column [INFERRED 0.85]
- **** —  [INFERRED 0.90]
- **** —  [INFERRED 0.90]
- **** —  [INFERRED 0.90]

## Communities (162 total, 80 thin omitted)

### Community 0 - "Database Schema Constants"
Cohesion: 0.02
Nodes (88): colDraftAuctionEndAt, colDraftAuctionStartAt, colDraftBatchNumber, colDraftBrand, colDraftCategory, colDraftCreatedAt, colDraftDefaultUnit, colDraftDropIntervalMinutes (+80 more)

### Community 1 - "Test Qa"
Cohesion: 0.06
Nodes (25): close, fetch, jsonResponse, main, MockHttpClientAdapter, build, buildCount, close (+17 more)

### Community 2 - "Home Feature Models"
Cohesion: 0.05
Nodes (39): auctionEndAt, auctionStartAt, batchNumber, brand, category, city, color, companyName (+31 more)

### Community 3 - "Local Database Service"
Cohesion: 0.06
Nodes (34): _appDatabase, clearListings, clearOrders, clearPrefs, clearScores, clearSyncedDrafts, _db, deleteDraft (+26 more)

### Community 4 - "Data Models"
Cohesion: 0.06
Nodes (33): auctionEndAt, auctionStartAt, batchNumber, brand, cachedAt, CachedListingModel, category, copyWith (+25 more)

### Community 5 - "Postgres Best Practices Docs"
Cohesion: 0.06
Nodes (33): Composite Index, Leftmost Prefix Rule, PostgreSQL Multicolumn Indexes documentation, Covering Index (INCLUDE), Index-Only Scan, PostgreSQL Index-Only Scans documentation, BRIN Index, B-tree Index (+25 more)

### Community 6 - "Backend App"
Cohesion: 0.14
Nodes (19): app_metadata, get_current_user(), require_role(), role_checker(), AppException, create_access_token(), create_refresh_token(), decode_token() (+11 more)

### Community 7 - "Token Storage"
Cohesion: 0.06
Nodes (27): accessToken, androidOptions, clearTokens, copyWith, expiresIn, fromJson, getAccessToken, getRefreshToken (+19 more)

### Community 8 - "Data Models"
Cohesion: 0.06
Nodes (31): auctionEndAt, auctionStartAt, batchNumber, brand, category, copyWith, create, createdAt (+23 more)

### Community 9 - " Claude Skills"
Cohesion: 0.07
Nodes (31): bitmap scan, composite index, leftmost prefix rule, Multicolumn Indexes documentation, covering index, INCLUDE clause, index-only scan, Index-Only Scans documentation (+23 more)

### Community 10 - " Agents Skills"
Cohesion: 0.07
Nodes (30): Feedback Issue Template, Skill Feedback, Supabase Skill, anon key, auth.role() deprecation, BOLA/IDOR, ClickHouse, Supabase Data (REST) API (+22 more)

### Community 11 - "Backend App"
Cohesion: 0.19
Nodes (9): init_db(), health_check(), lifespan(), get_rates(), ErrorDetail, ErrorEnvelope, ResponseEnvelope, wrap_success() (+1 more)

### Community 12 - "Auth UI & Screens"
Cohesion: 0.07
Nodes (25): backgroundColor, build, _buildChild, child, controller, filled, foregroundColor, hint (+17 more)

### Community 13 - "Lib Features"
Cohesion: 0.08
Nodes (23): _GoogleLogo, _OrDivider, _ValidCheckIcon, _ProfileHeader, _ProfileMenuList, ProfileScreen, _VerifiedBadge, _OfficialBadge (+15 more)

### Community 14 - "Backend App"
Cohesion: 0.16
Nodes (11): get_settings(), Settings, extract_invoice(), get_price_advice(), InvoiceOcrResponse, InvoiceParsedItem, PriceAdviceRequest, PriceAdviceResponse (+3 more)

### Community 15 - "Backend App"
Cohesion: 0.18
Nodes (11): Order, Buyer, DeviceToken, Seller, _format_order(), get_order_detail(), list_orders(), update_order_status() (+3 more)

### Community 16 - "Backend App"
Cohesion: 0.14
Nodes (11): create_product(), list_products(), ListingBuyRequest, ListingCreate, ListingDetailResponse, ListingResponse, ListingUpdate, MultiTimezoneSchedule (+3 more)

### Community 17 - "Lib Data"
Cohesion: 0.09
Nodes (8): ApiClient, AuthApiService, client, getProfile, login, logout, refreshToken, register

### Community 18 - "Stok Inventory Feature"
Cohesion: 0.08
Nodes (20): build, _buildActiveFilterTags, _buildCategoryRow, _buildLocationBar, _buildProductList, _buildSearchBar, _buildStickyHeader, _buildSubHeader (+12 more)

### Community 19 - "Data Repositories"
Cohesion: 0.08
Nodes (24): cacheListings, clearSyncedDrafts, deleteDraft, DraftSyncResult, errorMessage, errors, failedCount, fetchRemoteListings (+16 more)

### Community 20 - "Auth UI & Screens"
Cohesion: 0.08
Nodes (20): _WaveCardClipper, _agreeTerms, build, createState, dispose, _emailCtrl, _formKey, getClip (+12 more)

### Community 21 - "Backend App"
Cohesion: 0.20
Nodes (11): Listing, buy_listing(), create_listing(), _format_listing_response(), get_listing_detail(), get_my_listings(), list_listings(), update_listing() (+3 more)

### Community 22 - "Postgres Best Practices Docs"
Cohesion: 0.13
Nodes (10): Use tsvector for full-text search rule, Index JSONB columns rule, Configure idle connection timeouts rule, Set appropriate connection limits rule, Use connection pooling rule, Use prepared statements correctly with pooling rule, Batch INSERT statements rule, Eliminate N+1 queries rule (+2 more)

### Community 23 - "Data Repositories"
Cohesion: 0.09
Nodes (15): AuthTokens, authApiService, AuthRepository, _currentTokens, _currentUserProfile, fetchProfile, init, _instance (+7 more)

### Community 24 - "Auth UI & Screens"
Cohesion: 0.09
Nodes (14): build, _buildHeaderGraphic, createState, didChangeDependencies, dispose, _emailCtrl, _formKey, getClip (+6 more)

### Community 25 - "Core Constants"
Cohesion: 0.09
Nodes (19): ApiConstants, baseUrl, errorExpiredRefreshToken, errorInvalidRefreshToken, errorUserNotFound, errorValidationError, keyAccessToken, keyExpiresIn (+11 more)

### Community 26 - " Claude Skills"
Cohesion: 0.11
Nodes (21): Configure Idle Connection Timeouts, Set Appropriate Connection Limits, Use Connection Pooling for All Applications, Use Prepared Statements Correctly with Pooling, client_idle_timeout, Connection pooling, DEALLOCATE, idle_in_transaction_session_timeout (+13 more)

### Community 28 - "Data Models"
Cohesion: 0.10
Nodes (20): batchNumber, buyerId, cachedAt, CachedOrderModel, category, copyWith, createdAt, finalUnitPrice (+12 more)

### Community 29 - "Test Data Layer"
Cohesion: 0.10
Nodes (17): ListingRepository, RemoteListingClient, appDatabase, db, fetchRemoteListings, gameRepo, listingRepo, localDbService (+9 more)

### Community 30 - "Auth UI & Screens"
Cohesion: 0.10
Nodes (16): build, _city, _company, context, createState, _FloatingAvatar, icon, iconBg (+8 more)

### Community 31 - "Lib Core Theme"
Cohesion: 0.11
Nodes (17): accent, AppColors, border, canvasBg, darkNavy, error, inputBg, primary (+9 more)

### Community 32 - "Core Networking"
Cohesion: 0.11
Nodes (15): _handleSessionTermination, _isPublicPath, noAuthExtraKey, onError, onRequest, onSessionExpired, _performOrJoinRefresh, _refreshCompleter (+7 more)

### Community 33 - "Seed Buyer"
Cohesion: 0.24
Nodes (11): Buyer, CourseFeedback, Donation, Listing, Offer, Offtaker, Order, Product (+3 more)

### Community 34 - "Data Repositories"
Cohesion: 0.11
Nodes (17): AppPrefsRepository, clearAllPrefs, deletePref, getAllPrefs, getBool, getInt, getLastCurrencyRates, getSelectedTimezone (+9 more)

### Community 35 - "Home Feature Models"
Cohesion: 0.11
Nodes (16): build, _buildCategorySection, _buildExpirySection, _buildSortSection, _categories, createState, _expiryChip, _expiryLabel (+8 more)

### Community 36 - "Backend App"
Cohesion: 0.14
Nodes (5): register_device_token(), list_notifications(), mark_notification_read(), DeviceTokenRequest, NotificationResponse

### Community 37 - "Core Networking"
Cohesion: 0.12
Nodes (5): _authInterceptor, _dio, _tokenStorage, updateBaseUrl, AuthInterceptor

### Community 38 - "Lib Features Shell"
Cohesion: 0.13
Nodes (9): build, createState, _currentIndex, icon, isActive, label, _NavItem, onTap (+1 more)

### Community 39 - "Backend App"
Cohesion: 0.32
Nodes (8): login(), logout(), refresh_token(), register(), LoginRequest, LogoutRequest, RefreshRequest, RegisterRequest

### Community 40 - "Backend App"
Cohesion: 0.27
Nodes (7): _build_profile_response(), get_profile(), update_profile(), BuyerProfile, ProfileResponse, ProfileUpdateRequest, SellerProfile

### Community 41 - "Database Schema Constants"
Cohesion: 0.13
Nodes (9): AppDatabase, close, createTables, _database, _initDatabase, instance, _onUpgrade, reset (+1 more)

### Community 42 - " Claude Skills"
Cohesion: 0.16
Nodes (14): Writing Guidelines for Postgres References, Eliminate N+1 Queries with Batch Loading, Supabase Postgres Best Practices Skill, ANY operator, Batch loading, Crunchy Data, Impact levels, N+1 query (+6 more)

### Community 43 - "Docs Recovera Database"
Cohesion: 0.16
Nodes (14): ESG Certificate, buyers table, course_feedbacks table, device_tokens table, donations table, listings table, notifications table, offers table (+6 more)

### Community 44 - "Auth UI & Screens"
Cohesion: 0.14
Nodes (10): AuthHeader, build, child, HeaderIconButton, height, icon, leftAction, onTap (+2 more)

### Community 45 - "Auth UI & Screens"
Cohesion: 0.14
Nodes (13): address, businessType, city, companyName, email, fromJson, id, name (+5 more)

### Community 46 - "Lib Features"
Cohesion: 0.20
Nodes (12): LoginScreen, _LoginScreenState, _ProfileMenuItem, _ProfileMenuItemState, RegisterScreen, _RegisterScreenState, FilterBottomSheet, _FilterBottomSheetState (+4 more)

### Community 47 - "Lib Features"
Cohesion: 0.15
Nodes (6): AppTheme, light, build, SaranKesanScreen, build, HomeScreen

### Community 48 - "Backend Tests Conftest"
Cohesion: 0.19
Nodes (5): get_db(), Offtaker, client(), db_session(), setup_test_db()

### Community 49 - "Lib Core Navigation"
Cohesion: 0.15
Nodes (6): AppNavigator, handleSessionExpired, _isHandlingSessionExpired, navigatorKey, scaffoldMessengerKey, showSessionExpiredSnackBar

### Community 50 - "Data Models"
Cohesion: 0.15
Nodes (10): badge, copyWith, create, fromMap, GameScoreModel, id, itemsSaved, playedAt (+2 more)

### Community 51 - "Data Repositories"
Cohesion: 0.15
Nodes (11): cacheOrder, cacheOrders, clearOrderCache, fetchRemoteOrderDetail, fetchRemoteOrders, getOrderById, getOrders, _localDb (+3 more)

### Community 52 - "Backend App"
Cohesion: 0.29
Nodes (6): verify_tx_hash(), BlockchainVerifyResponse, CertificateCurrencyBreakdown, CertificateResponse, get_donation_certificate(), verify_blockchain_hash()

### Community 53 - "Lib Main"
Cohesion: 0.17
Nodes (5): build, initialize, main, RecoveraApp, setPreferredOrientations

### Community 54 - " Claude Skills"
Cohesion: 0.20
Nodes (11): Batch INSERT Statements for Bulk Data, Keep Transactions Short to Reduce Lock Contention, Reference Template, Batch INSERT, Bulk loading, COPY command, Lock contention, PostgreSQL documentation (+3 more)

### Community 55 - " Claude Skills"
Cohesion: 0.20
Nodes (11): Use Advisory Locks for Application-Level Locking, Prevent Deadlocks with Consistent Lock Ordering, Advisory lock, Deadlock, deadlock_timeout, Lock ordering, log_lock_waits, pg_advisory_lock (+3 more)

### Community 56 - "Backend App"
Cohesion: 0.29
Nodes (6): register_exception_handlers(), app_exception_handler(), general_exception_handler(), http_exception_handler(), validation_exception_handler(), wrap_error()

### Community 57 - "Backend App"
Cohesion: 0.22
Nodes (4): CourseFeedback, submit_feedback(), FeedbackRequest, FeedbackResponse

### Community 58 - "Lib Data"
Cohesion: 0.18
Nodes (8): clearGameHistory, GameRepository, getLeaderboard, getRecentScores, getTotalItemsSaved, _localDb, recordGameScore, LocalDatabaseService

### Community 60 - " Claude Skills"
Cohesion: 0.20
Nodes (8): FORCE ROW LEVEL SECURITY, RLS policy, Row Level Security (RLS), Row Level Security guide, index on RLS policy column, RLS Performance recommendations, RLS policy performance, SECURITY DEFINER function

### Community 61 - "Backend App"
Cohesion: 0.29
Nodes (4): Product, calculate_haversine_distance(), format_multi_timezone(), search_listings()

### Community 62 - "Data Models"
Cohesion: 0.20
Nodes (8): AppPrefModel, copyWith, create, fromMap, key, toMap, updatedAt, value

### Community 63 - "Web Manifest"
Cohesion: 0.20
Nodes (9): background_color, display, icons, name, orientation, prefer_related_applications, short_name, start_url (+1 more)

### Community 64 - " Claude Skills"
Cohesion: 0.25
Nodes (9): Use tsvector for Full-Text Search, Full-text search, GIN index, JSONB, LIKE pattern matching, to_tsquery, to_tsvector, ts_rank (+1 more)

### Community 65 - " Claude Skills"
Cohesion: 0.25
Nodes (9): Section Definitions, Advanced Features, Concurrency & Locking, Connection Management, Data Access Patterns, Monitoring & Diagnostics, Query Performance, Schema Design (+1 more)

### Community 66 - "Postgres Best Practices Docs"
Cohesion: 0.25
Nodes (9): Principle of Least Privilege, Database Role, Supabase Roles and Privileges blog post, Supabase Row Level Security documentation, RLS Policy, Row Level Security (RLS), RLS Policy Performance, Supabase RLS Performance recommendations (+1 more)

### Community 67 - "Backend Tests Test"
Cohesion: 0.28
Nodes (3): Donation, test_ai_endpoints(), test_auxiliary_endpoints()

### Community 68 - " Claude Skills"
Cohesion: 0.25
Nodes (8): EXPLAIN ANALYZE, query execution plan, Sequential Scan, Supabase database inspect guide, mean_exec_time, pg_stat_statements extension, pg_stat_statements extension guide, total_exec_time

### Community 69 - "Home Feature Models"
Cohesion: 0.25
Nodes (5): build, EmptyStateView, _Illustration, onResetFilter, onShowAll

### Community 70 - " Claude Skills"
Cohesion: 0.33
Nodes (7): BRIN index, B-tree index, choose the right index type, GIN index, GiST index, Hash index, Index Types documentation

### Community 71 - "Postgres Best Practices Docs"
Cohesion: 0.33
Nodes (7): EXPLAIN ANALYZE, Supabase EXPLAIN documentation, pg_stat_statements, Supabase pg_stat_statements extension documentation, autovacuum, VACUUM and ANALYZE, Supabase VACUUM operations documentation

### Community 72 - " Claude Skills"
Cohesion: 0.33
Nodes (6): Index JSONB Columns for Efficient Querying, @> containment operator, Expression index, JSONB GIN index, jsonb_ops operator class, jsonb_path_ops operator class

### Community 73 - " Claude Skills"
Cohesion: 0.33
Nodes (6): bigint, appropriate data type selection, Data Types documentation, numeric, text, timestamptz

### Community 74 - "Postgres Best Practices Docs"
Cohesion: 0.33
Nodes (6): Keep Transactions Short to Reduce Lock Contention, statement_timeout, PostgreSQL Transaction Management documentation, SELECT FOR UPDATE SKIP LOCKED, PostgreSQL SELECT FOR UPDATE SKIP LOCKED documentation, SKIP LOCKED for Non-Blocking Queue Processing

### Community 76 - " Claude Skills"
Cohesion: 0.50
Nodes (5): Use UPSERT for Insert-or-Update Operations, DO NOTHING, INSERT ON CONFLICT, Race condition, UPSERT

### Community 77 - " Claude Skills"
Cohesion: 0.40
Nodes (5): ANALYZE, autovacuum, pg_stat_user_tables, VACUUM, VACUUM database size guide

### Community 78 - " Claude Skills"
Cohesion: 0.40
Nodes (5): partition, partition pruning, range partitioning, table partitioning, Table Partitioning documentation

### Community 80 - " Claude Skills"
Cohesion: 0.67
Nodes (4): Use Cursor-Based Pagination Instead of OFFSET, Cursor-based pagination, Keyset pagination, OFFSET pagination

### Community 81 - " Claude Skills"
Cohesion: 0.50
Nodes (4): PostgreSQL SELECT FOR UPDATE SHARE documentation, SELECT FOR UPDATE, SKIP LOCKED clause, worker queue

### Community 82 - " Claude Skills"
Cohesion: 0.50
Nodes (4): Identifiers and Key Words documentation, lowercase identifier, quoted mixed-case identifier, snake_case naming

### Community 83 - " Claude Skills"
Cohesion: 0.50
Nodes (4): database role, GRANT / REVOKE, principle of least privilege, Roles and Privileges guide

### Community 84 - "Docs Recovera"
Cohesion: 0.50
Nodes (4): recovera_api container, Recovera Backend API, Recovera PRD (full platform), Product Backlog (PBI-01..PBI-23)

### Community 86 - "Docs Recovera"
Cohesion: 0.67
Nodes (3): flutter_secure_storage, flutter_secure_storage, flutter_secure_storage

## Knowledge Gaps
- **865 isolated node(s):** `recovera-backend`, `ApiConstants`, `baseUrl`, `registerEndpoint`, `loginEndpoint` (+860 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1053 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **80 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `wrap_success()` connect `Backend App` to `Backend App`, `Backend App`, `Backend App`, `Backend App`, `Backend API Routes`, `Backend App`, `Backend App`, `Backend App`, `Backend App`, `Backend App`, `Backend App`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._
- **Are the 7 inferred relationships involving `AppException` (e.g. with `extract_invoice()` and `create_listing()`) actually correct?**
  _`AppException` has 7 INFERRED edges - model-reasoned connections that need verification._
- **What connects `recovera-backend`, `ApiConstants`, `baseUrl` to the rest of the system?**
  _865 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Database Schema Constants` be split into smaller, more focused modules?**
  _Cohesion score 0.022222222222222223 - nodes in this community are weakly interconnected._
- **Why does `JSON Web Token (JWT)` connect `Backend App` to ` Agents Skills`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._
- **Are the 10 inferred relationships involving `Listing` (e.g. with `create_listing()` and `_format_listing_response()`) actually correct?**
  _`Listing` has 10 INFERRED edges - model-reasoned connections that need verification._
- **Should `Test Qa` be split into smaller, more focused modules?**
  _Cohesion score 0.06342494714587738 - nodes in this community are weakly interconnected._