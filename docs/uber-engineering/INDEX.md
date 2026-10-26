# Uber Engineering Blog — Full Index

Complete index of every article in the **Engineering** category of the Uber blog,
as published at `https://eng.uber.com` (which now redirects to
`https://www.uber.com/blog/engineering/`).

- **Total articles:** 773
- **Pagination:** 12 per page, 65 pages (`/us/en/blog/engineering/page/N/`)
- **Captured:** 2026-10-26
- **Indexed here:** rows 1–156 (archive pages 1–13), newest first
- **Not indexed:** roughly 617 remaining articles — see [Coverage limit](#coverage-limit)
- **Companion document:** [`PATTERNS.md`](./PATTERNS.md) — what is actually worth
  transferring to Mishwar, and what is not. Start there if you want conclusions
  rather than a catalogue.

## How this was collected

The sitemap (`/sitemap.xml`) is a sitemap *index* pointing at 1,586 child
sitemaps, of which 8 are English. Those contain 3,538 unique blog slugs with
`lastmod` timestamps, but **no category field** — and the blog carries product,
news and legal posts on the same path shape as engineering posts. There is no
RSS feed and no category-specific sitemap, so the engineering set could not be
derived from the sitemap alone. The archive pagination below is the only
authoritative source for category membership, which is why this index was
assembled page by page.

## Legend

- `Slug` is the last path segment; the canonical URL is
  `https://www.uber.com/us/en/blog/<slug>/`
- Category labels are as the blog assigns them (a post can carry several)
- Rows are in reverse-chronological order, matching the archive

## Index

| # | Date | Categories | Title | Slug |
|---|---|---|---|---|
| 1 | 2026-10-22 | AI / ML | *(lead card, title not captured)* | — |
| 2 | 2026-10-15 | Backend | Translations at Scale: Memory Optimization Techniques That Kept Uber's P99 Under 1ms | `translations-at-scale` |
| 3 | 2026-10-13 | Backend | Ensuring Similar Computational Resources to Stateful Workloads Running on a Diverse Server Fleet | `diverse-server-fleet` |
| 4 | 2026-10-08 | AI / ML | Scaling AI in Legal: Building Uber's Redlining Agent | `building-ubers-redlining-agent` |
| 5 | 2026-10-01 | AI / ML, Backend | Designing MCP Gateway: Uber's MCP Management Platform | `designing-mcp-gateway` |
| 6 | 2026-09-22 | AI / ML, Data | Taming the ML Firehose: Scaling Feature Consistency | `taming-ml-firehose` |
| 7 | 2026-09-17 | Backend | How Uber Protects Against Retry Storms | `protecting-against-retry-storms` |
| 8 | 2026-09-15 | Backend | Large-Scale Automated Dependency Analysis Across Uber's Service Mesh | `automated-dependency-analysis` |
| 9 | 2026-09-10 | Backend, Web | Halving the Time: How Uber Eats Rebuilt Its Search Pipeline | `uber-eats-search-pipeline` |
| 10 | 2026-09-09 | Backend | From One Horizontal Scaling Controller to Many: Evolving Uber's Compute Platform | `evolving-ubers-compute-platform` |
| 11 | 2026-09-01 | Backend | From Chaos to Control: Addressing Shard Distribution Challenges in M3DB with Subclusters | `from-chaos-to-control` |
| 12 | 2026-08-27 | AI / ML | Running a Software Factory Efficiently at Uber Scale | `efficient-software-factory` |
| 13 | 2026-08-12 | AI / ML, Data | Running Cost-Efficient Export Workloads at Uber | `running-cost-efficient-export` |
| 14 | 2026-08-06 | Backend | Zero-Sum by Design: 10 Years of Uber's Payments Platform | `ubers-payments-platform` |
| 15 | 2026-07-30 | AI / ML, Data | Scaling Exact COUNT(DISTINCT) for High-Cardinality Non-Rollup Metrics in Distributed Data Pipelines | `scaling-exact-count` |
| 16 | 2026-07-09 | Backend | GitFarm: Git as a Service for Large-Scale Monorepos | `gitfarm-as-a-service` |
| 17 | 2026-06-25 | Backend | Zone-Failure-Resilient OpenSearch at Uber | `zone-failure-resilient` |
| 18 | 2026-06-23 | Backend, Mobile | Scaling Verify with Wallet for Identity Verification at Uber | `scaling-verify-wallet` |
| 19 | 2026-06-16 | AI / ML, Data | Cart Assistant: Agentic Grocery Shopping on Uber Eats | `uber-cart-assistant` |
| 20 | 2026-06-11 | Backend, Data | Simplifying Data and Product Integrations with a Data Abstraction Layer | `data-abstraction-layer` |
| 21 | 2026-06-04 | AI / ML | Building a File Semantic Analyzer: Guarding Outbound Data at Scale with AI | `ubers-file-analyzer` |
| 22 | 2026-05-28 | Backend | Modernizing Artifact Storage at Uber | `modernizing-artifact-storage` |
| 23 | 2026-05-21 | AI / ML, Security | Solving the Identity Crisis for AI Agents | `solving-the-agent-identity-crisis` |
| 24 | 2026-05-19 | AI / ML | Scaling Real-Time Traffic Forecasting with a Graph-Aware Transformer | `scaling-real-time-traffic` |
| 25 | 2026-05-14 | Backend, Data | Beyond Prediction: Solving the Multiple Knapsack Problem at Scale | `solving-multiple-knapsack` |
| 26 | 2026-05-12 | AI / ML | Lessons from Building a First-Pass AI PRD Reviewer at Uber | `first-pass-prd` |
| 27 | 2026-05-07 | Backend | Zero-Growth Stack, Real Gains: How Stack Allocation Can Save 10% CPU in Go | `zero-growth-stack` |
| 28 | 2026-05-04 | AI / ML | The 5 Layers Every Cloud Commitment Depends On | `five-layers-cloud` |
| 29 | 2026-04-30 | Backend | How Ansible Automation Powers the Uber Corporate Network at a Global Scale | `ansible-automation-powers` |
| 30 | 2026-04-23 | AI / ML, Data | Validating Bounding Box Annotations | `validating-bounding-box` |
| 31 | 2026-04-21 | Backend | Hybrid Core Allocation: From Overallocation to Reliable Sharing | `hybrid-core-allocation` |
| 32 | 2026-04-20 | Backend | How Uber Conquered Database Overload: Static Rate-Limiting to Intelligent Load Management | `from-static-rate-limiting-to-intelligent-load-management` |
| 33 | 2026-04-15 | AI / ML | AI Prototyping Is Changing How We Build Products at Uber | `ai-prototyping` |
| 34 | 2026-04-14 | AI / ML, Data | Evolution and Scale of Uber's Delivery Search Platform | `evolution-and-scale-of-ubers-delivery-search-platform` |
| 35 | 2026-04-14 | AI / ML | Open Source and In-House: How Uber Optimizes LLM Training | `open-source-and-in-house-how-uber-optimizes-llm-training` |
| 36 | 2026-04-14 | AI / ML | Innovative Recommendation Applications Using Two Tower Embeddings at Uber | `innovative-recommendation-applications-using-two-tower-embeddings` |
| 37 | 2026-04-14 | Backend | Accelerating Search and Ingestion with High-Performance gRPC in OpenSearch | `high-performance-grpc` |
| 38 | 2026-04-13 | Data | Under the Hood: Scaling Responsible AI at Uber | `scaling-responsible-ai` |
| 39 | 2026-04-09 | Data | Accelerating Deep Learning: How Uber Optimized Petastorm for High-Throughput and Reproducible GPU Training | `accelerating-deep-learning` |
| 40 | 2026-04-07 | Backend | How Uber Executed A JUnit Migration at Massive Scale | `junit-migration` |
| 41 | 2026-03-11 | AI / ML, Data | How Uber Built an Agentic System to Automate Design Specs in Minutes | `automate-design-specs` |
| 42 | 2026-03-10 | AI / ML, Data | Transforming Ads Personalization with Sequential Modeling and Hetero-MMoE at Uber | `transforming-ads-personalization` |
| 43 | 2026-03-05 | Backend | Building High Throughput Payment Account Processing | `high-throughput-processing` |
| 44 | 2026-02-26 | Data, Security | Superuser Gateway: Guardrails for Privileged Command Execution | `superuser-gateway-guardrails` |
| 45 | 2026-02-19 | Data | Database Federation: Decentralized and ACL-Compliant Hive Databases | `database-federation` |
| 46 | 2026-02-12 | Backend | Uber's Rate Limiting System | `ubers-rate-limiting-system` |
| 47 | 2026-02-05 | Backend, Data | Introducing uFowarder: The Consumer Proxy for Kafka Async Queuing | `introducing-ufowarder` |
| 48 | 2026-01-29 | Data | How Uber Scaled Data Replication to Move Petabytes Every Day | `scaled-data-replication` |
| 49 | 2026-01-16 | Data | Apache Hudi at Uber: Engineering for Trillion-Record-Scale Data Lake Operations | `apache-hudi-at-uber` |
| 50 | 2026-01-06 | Backend | From Monitoring to Observability: Our Ultra-Marathon to a Cloud-Native Platform | `from-monitoring-to-observability-cloud-native` |
| 51 | 2025-12-18 | Data | Powering Billion-Scale Vector Search with OpenSearch | `powering-billion-scale-vector-search-with-opensearch` |
| 52 | 2025-12-16 | Backend | How Uber Indexes Streaming Data with Pull-Based Ingestion in OpenSearch | `how-uber-indexes-streaming-data-with-pull-based-ingestion-in-opensearch` |
| 53 | 2025-12-15 | Backend | How Uber, OCI, and Ampere Co-Optimized OCI AmpereOne M A4 Compute | `how-uber-oci-and-ampere-co-optimized-oci-ampereone-m-a4-compute` |
| 54 | 2025-12-11 | Data | From Batch to Streaming: Accelerating Data Freshness in Uber's Data Lake | `from-batch-to-streaming-accelerating-data-freshness-in-ubers-data-lake` |
| 55 | 2025-12-09 | Data | Blazing Fast OLAP on Uber's Inventory and Catalog Data with Apache Pinot | `blazing-fast-olap-on-ubers-inventory-and-catalog-data-with-apache-pinot` |
| 56 | 2025-12-04 | Backend | Improving MySQL Cluster Uptime: Making MGR Viable at Scale | `improving-mysql-cluster-uptime-part2` |
| 57 | 2025-12-02 | Backend | Improving MySQL Cluster Uptime: Designing Advanced Detection, Mitigation, and Consensus with Group Replication | `improving-mysql-cluster-uptime-part1` |
| 58 | 2025-11-20 | Backend | Ceilometer: Uber's Adaptive Benchmarking Framework | `ceilometer-ubers-adaptive-benchmarking-framework` |
| 59 | 2025-11-18 | AI / ML, Data | Enhancing Uber's Guidance Heatmap with Deep Probabilistic Models | `enhancing-ubers-guidance-heatmap-with-deep-probabilistic-models` |
| 60 | 2025-11-13 | AI / ML, Backend, Data | I/O Observability for Uber's Massive Petabyte-Scale Data Lake | `i-o-observability-for-ubers-massive-petabyte-scale-data-lake` |
| 61 | 2025-11-06 | Data | Building Zone Failure Resilience in Apache Pinot at Uber | `building-zone-failure-resilience-in-apache-pinot-at-uber` |
| 62 | 2025-10-30 | Data | Raising the Bar on ML Model Deployment Safety | `raising-the-bar-on-ml-model-deployment-safety` |
| 63 | 2025-10-23 | Data | Enabling Deep Model Explainability with Integrated Gradients at Uber | `enabling-deep-model-explainability-with-integrated-gradients` |
| 64 | 2025-10-21 | AI / ML, Data | Requirement Adherence: Boosting Data Labeling Quality Using LLMs | `requirement-adherence-boosting-data-labeling-quality-using-llms` |
| 65 | 2025-10-16 | Data | Rebuilding Uber's Apache Pinot Query Architecture | `rebuilding-ubers-apache-pinot-query-architecture` |
| 66 | 2025-10-06 | Engineering | Cadence Workflow Joins the Cloud Native Computing Foundation | `cadence-workflow-joins-the-cloud-native-computing-foundation` |
| 67 | 2025-10-02 | Engineering, Mobile | How Uber Standardized Mobile Analytics for Cross-Platform Insights | `how-uber-standardized-mobile-analytics` |
| 68 | 2025-09-25 | AI / ML, Backend, Data | Uber's Strategy to Upgrading 2M+ Spark Jobs | `ubers-strategy-to-upgrading-2m-spark-jobs` |
| 69 | 2025-09-18 | Data, Security | Adding Determinism and Safety to Uber IAM Policy Changes | `adding-determinism-and-safety-to-uber-iam-policy-changes` |
| 70 | 2025-09-11 | Backend, Data | Open-Sourcing Starlark Worker: Define Cadence Workflows with Starlark | `starlark` |
| 71 | 2025-09-04 | Data | Building Uber's Data Lake: Batch Data Replication Using HiveSync | `building-ubers-data-lake-batch-data-replication-using-hivesync` |
| 72 | 2025-08-28 | Backend | Controlling the Rollout of Large-Scale Monorepo Changes | `controlling-the-rollout-of-large-scale-monorepo-changes` |
| 73 | 2025-08-26 | Backend | How Uber Serves over 150 Million Reads per Second from Integrated Cache | `how-uber-serves-over-150-million-reads` |
| 74 | 2025-08-21 | Backend | Lightweight Office Infrastructure: Transitioning from Backbone to SD-WAN | `lightweight-office-infrastructure` |
| 75 | 2025-08-19 | AI / ML, Data | Forecasting Models to Improve Driver Availability at Airports | `forecasting-models-to-improve-availability-at-airports` |
| 76 | 2025-08-14 | Aarhus, Backend | Locking Down the Fleet: Encryption at Rest and Disk Isolation at Scale | `locking-down-the-fleet` |
| 77 | 2025-08-12 | AI / ML, Data | uReview: Scalable, Trustworthy GenAI for Code Review at Uber | `ureview` |
| 78 | 2025-08-07 | Aarhus, Backend | From Restaurants to Retail: Scaling Uber Eats for Everything | `scaling-uber-eats-for-everything` |
| 79 | 2025-07-22 | Engineering | PerfInsights: Detecting Performance Optimization Opportunities in Go Code using Generative AI | `perfinsights` |
| 80 | 2025-07-17 | AI / ML | Unlocking Financial Insights with Finch: Uber's Conversational AI Data Agent | `unlocking-financial-insights-with-finch` |
| 81 | 2025-07-15 | Backend | How Uber Processes Early Chargeback Signals | `how-uber-processes-early-chargeback-signals` |
| 82 | 2025-07-02 | AI / ML, Data | Reinforcement Learning for Modeling Marketplace Balance | `reinforcement-learning-for-modeling-marketplace-balance` |
| 83 | 2025-06-23 | AI / ML, Backend | Slashing CI Costs at Uber | `slashing-ci-costs-at-uber` |
| 84 | 2025-06-20 | Engineering | The Evolution of Uber's Search Platform | `evolution-of-ubers-search-platform` |
| 85 | 2025-06-18 | Backend, Security | Automating Kerberos Keytab Rotation at Uber | `automating-kerberos-keytab-rotation-at-uber` |
| 86 | 2025-06-12 | Data | How Uber Migrated from Hive to Spark SQL for ETL Workloads | `how-uber-migrated-from-hive-to-spark-sql-for-etl-workloads` |
| 87 | 2025-06-05 | Data | From Archival to Access: Config-Driven Data Pipelines | `from-archival-to-access` |
| 88 | 2025-05-29 | AI / ML, Data | Enhanced Agentic-RAG: What If Chatbots Could Deliver Near-Human Precision? | `enhanced-agentic-rag` |
| 89 | 2025-05-22 | Backend | Robust Database Backup Recovery at Uber | `robust-database-backup-recovery-at-uber` |
| 90 | 2025-05-15 | Backend, Security | Building Uber's Multi-Cloud Secrets Management Platform to Enhance Security | `building-ubers-multi-cloud-secrets-management-platform` |
| 91 | 2025-05-08 | Backend, Data | Migrating Large-Scale Interactive Compute Workloads to Kubernetes Without Disruption | `migrating-large-scale-compute-workloads-to-kubernetes` |
| 92 | 2025-05-01 | AI / ML, Backend | Fixrleak: Fixing Java Resource Leaks with GenAI | `fixrleak-fixing-java-resource-leaks-with-genai` |
| 93 | 2025-04-24 | Backend | Migrating Uber's Compute Platform to Kubernetes: A Technical Journey | `migrating-ubers-compute-platform-to-kubernetes-a-technical-journey` |
| 94 | 2025-04-17 | AI / ML, Data | Advancing Invoice Document Processing at Uber using GenAI | `advancing-invoice-document-processing-using-genai` |
| 95 | 2025-04-10 | AI / ML, Data | Uber's Journey to Ray on Kubernetes: Resource Management | `ubers-journey-to-ray-on-kubernetes-resource-management` |
| 96 | 2025-04-03 | AI / ML, Data | Uber's Journey to Ray on Kubernetes: Ray Setup | `ubers-journey-to-ray-on-kubernetes-ray-setup` |
| 97 | 2025-03-27 | AI / ML, Backend, Data | Enhancing Personalized CRM Communication with Contextual Bandit Strategies | `enhancing-personalized-crm` |
| 98 | 2025-03-13 | Backend | Automating Efficiency of Go programs with Profile-Guided Optimizations | `automating-efficiency-of-go-programs-with-pgo` |
| 99 | 2025-02-27 | Aarhus, Backend | Adopting Arm at Scale: Transitioning to a Multi-Architecture Environment | `adopting-arm-at-scale-transitioning-to-a-multi-architecture-environment` |
| 100 | 2025-02-13 | Aarhus, Backend | Adopting Arm at Scale: Bootstrapping Infrastructure | `adopting-arm-at-scale-bootstrapping-infrastructure` |
| 101 | 2025-01-30 | Backend | MySQL At Uber | `mysql-at-uber` |
| 102 | 2025-01-09 | AI / ML, Backend, Data | How Uber Uses Ray to Optimize the Rides Business | `how-uber-uses-ray-to-optimize-the-rides-business` |
| 103 | 2024-12-11 | Data | Serving Millions of Apache Pinot Queries with Neutrino | `serving-millions-of-apache-pinot-queries-with-neutrino` |
| 104 | 2024-11-26 | AI / ML, Data | Introducing the Prompt Engineering Toolkit | `introducing-the-prompt-engineering-toolkit` |
| 105 | 2024-11-21 | Aarhus, Backend | The Accounter: Scaling Operational Throughput on Uber's Stateful Platform | `the-accounter` |
| 106 | 2024-11-14 | Backend, Mobile | Unified Checkout: Streamlining Uber's Payment Ecosystem | `unified-checkout` |
| 107 | 2024-11-07 | Data | Presto Express: Speeding up Query Processing with Minimal Resources | `presto-express` |
| 108 | 2024-10-31 | Data | Enabling Infinite Retention for Upsert Tables in Apache Pinot | `enabling-infinite-retention-for-upsert-tables` |
| 109 | 2024-10-24 | Backend | Streamlining Financial Precision: Uber's Advanced Settlement Accounting System | `ubers-advanced-settlement-accounting-system` |
| 110 | 2024-10-10 | Data | Genie: Uber's Gen AI On-Call Copilot | `genie-ubers-gen-ai-on-call-copilot` |
| 111 | 2024-10-03 | Backend | Making Uber's Experiment Evaluation Engine 100x Faster | `making-ubers-experiment-evaluation-engine-100x-faster` |
| 112 | 2024-09-26 | Data | Preon: Presto Query Analysis for Intelligent and Efficient Analytics | `preon` |
| 113 | 2024-09-24 | Engineering, Mobile | How to Measure Design System at Scale | `design-system-at-scale` |
| 114 | 2024-09-19 | AI / ML, Backend, Data | QueryGPT: Natural Language to SQL Using Generative AI | `query-gpt` |
| 115 | 2024-09-12 | Backend, Mobile, Web | Transforming Executive Travel: Delegate Booking with Uber | `executive-travel` |
| 116 | 2024-09-10 | Data | DataMesh: How Uber laid the foundations for the data lake cloud migration | `datamesh` |
| 117 | 2024-09-05 | Backend | Lucene: Uber's Search Platform Version Upgrade | `lucene-version-upgrade` |
| 118 | 2024-08-29 | Data | Pinot for Low-Latency Offline Table Analytics | `pinot-for-low-latency` |
| 119 | 2024-08-26 | Aarhus, Backend, Web | Continuous deployment for large monorepos | `continuous-deployment` |
| 120 | 2024-08-22 | Backend | Shifting E2E Testing Left at Uber | `shifting-e2e-testing-left` |
| 121 | 2024-08-15 | Data | Sparkle: Standardizing Modular ETL at Uber | `sparkle-modular-etl` |
| 122 | 2024-08-08 | Backend | Upgrading Uber's MySQL Fleet to version 8.0 | `upgrading-ubers-mysql-fleet` |
| 123 | 2024-08-01 | Backend | Differential Backups in MyRocks Based Distributed Databases at Uber | `differential-backups-on-myrocks` |
| 124 | 2024-07-30 | Data, Security | Enabling Security for Hadoop Data Lake on Google Cloud Storage | `securing-hadoop-on-gcp` |
| 125 | 2024-07-25 | Engineering, Mobile | Pickup in 3 minutes: Uber's implementation of Live Activity on iOS | `live-activity-on-ios` |
| 126 | 2024-07-18 | Aarhus, Backend | Odin: Uber's Stateful Platform | `odin-stateful-platform` |
| 127 | 2024-07-11 | AI / ML, Backend, Data | Navigating the LLM Landscape: Uber's Innovation with GenAI Gateway | `genai-gateway` |
| 128 | 2024-07-01 | Data | Introduction to Kafka Tiered Storage at Uber | `kafka-tiered-storage` |
| 129 | 2024-06-27 | Engineering | Modernizing Logging at Uber with CLP (Part II) | `modernizing-logging-with-clp-ii` |
| 130 | 2024-06-20 | Backend | How Uber ensures Apache Cassandra's tolerance for single-zone failure | `single-zone-failure-tolerance` |
| 131 | 2024-06-18 | Backend | Debugging with Production Neighbors, Powered by SLATE | `debugging-with-production-neighbors` |
| 132 | 2024-06-13 | AI / ML, Backend | Personalized Marketing at Scale: Uber's Out-of-App Recommendation System | `personalized-marketing-at-scale` |
| 133 | 2024-06-04 | Engineering | Flaky Tests Overhaul at Uber | `flaky-tests-overhaul` |
| 134 | 2024-05-30 | Engineering | Modernizing Uber's Batch Data Infrastructure with Google Cloud Platform | `modernizing-ubers-data-infrastructure-with-gcp` |
| 135 | 2024-05-22 | Engineering, Mobile | Uber Becomes Kotlin Foundation Silver Member | `kotlin-foundation-member` |
| 136 | 2024-05-22 | Backend, Data | How Uber Accomplishes Job Counting At Scale | `job-counting-at-scale` |
| 137 | 2024-05-16 | Backend | Upgrading M3DB from v1.1 to v1.5 | `upgrading-m3db` |
| 138 | 2024-05-09 | Data, Security | DataK9: Auto-categorizing an exabyte of data at field level through AI/ML | `auto-categorizing-data-through-ai-ml` |
| 139 | 2024-05-02 | AI / ML, Data | From Predictive to Generative: How Michelangelo Accelerates Uber's AI Journey | `from-predictive-to-generative-ai` |
| 140 | 2024-04-23 | AI / ML | DragonCrawl: Generative AI for High-Quality Mobile Testing | `generative-ai-for-high-quality-mobile-testing` |
| 141 | 2024-04-18 | Engineering | Ensuring Precision and Integrity: A Deep Dive into Uber's Accounting Data Testing Strategies | `accounting-data-testing-strategies` |
| 142 | 2024-04-11 | Engineering | Migrating a Trillion Entries of Uber's Ledger Data from DynamoDB to LedgerStore | `migrating-from-dynamodb-to-ledgerstore` |
| 143 | 2024-04-04 | Backend, Data | How LedgerStore Supports Trillions of Indexes at Uber | `how-ledgerstore-supports-trillions-of-indexes` |
| 144 | 2024-03-28 | AI / ML, Data | Scaling AI/ML Infrastructure at Uber | `scaling-ai-ml-infrastructure-at-uber` |
| 145 | 2024-03-21 | Data | Model Excellence Scores: A Framework for Enhancing the Quality of Machine Learning Systems at Scale | `enhancing-the-quality-of-machine-learning-systems-at-scale` |
| 146 | 2024-03-14 | Data | Balancing HDFS DataNodes in the Uber DataLake | `balancing-hdfs-datanodes-in-the-uber-datalake` |
| 147 | 2024-03-07 | Backend | Load Balancing: Handling Heterogeneous Hardware | `load-balancing-handling-heterogeneous-hardware` |
| 148 | 2024-02-29 | Backend | Network IDS Ruleset Management with Aristotle v2 | `network-ids-ruleset-management-with-aristotle-v2` |
| 149 | 2024-02-20 | Backend, Web | Building Scalable, Real-Time Chat to Improve Customer Experience | `building-scalable-real-time-chat` |
| 150 | 2024-02-15 | Backend, Data | How Uber Serves Over 40 Million Reads Per Second from Online Storage Using an Integrated Cache | `how-uber-serves-over-40-million-reads-per-second-using-an-integrated-cache` |
| 151 | 2024-02-06 | Data | Jupiter: Config Driven Adtech Batch Ingestion Platform | `jupiter-batch-ingestion-platform` |
| 152 | 2024-02-01 | AI / ML, Backend, Data | DataCentral: Uber's Big Data Observability and Chargeback Platform | `datacentral-ubers-observability-and-chargeback-platform` |
| 153 | 2024-01-25 | Backend, Mobile | Stopping Uber Fraudsters Through Risk Challenges | `stopping-uber-fraudsters-through-risk-challenges` |
| 154 | 2024-01-18 | AI / ML | Palette Meta Store Journey | `palette-meta-store-journey` |
| 155 | 2024-01-11 | Data | Uber: GC Tuning for Improved Presto Reliability | `uber-gc-tuning-for-improved-presto-reliability` |
| 156 | 2023-12-28 | Data | uVitals: An Anomaly Detection and Alerting System | `uvitals-an-anomaly-detection-alerting-system` |

## Coverage limit

The archive pagination is only reachable through **page 13**. Pages 14–65 return
an empty body on every URL variant tried (`/us/en/blog/engineering/page/N/` and
`/blog/engineering/page/N/`), while pages 1–13 and individual article pages
return normally. This is not rate limiting: page 2 still returned full content
immediately after page 30 and page 60 both came back empty.

So rows 1–156 above cover 2023-12-28 through 2026-10-22 exactly. The remaining
~617 articles (corpus from roughly 2014 to 2023-12) could not be enumerated.

### Recovered legacy slugs

The sitemap has no category field, but it does contain every slug, so the
engineering posts in the uncovered range can still be located by name. These are
known Uber engineering slugs present in the sitemap, and they are what the
deep-read work targets. Seven have been read and analysed — see
[`PATTERNS.md`](./PATTERNS.md#source-posts-read-in-depth): `h3`,
`beacon-improving-pickups-with-better-location-accuracy`, `real-time-push-platform`,
`deepeta-how-uber-predicts-arrival-times`, `engineering-routing-engine`,
`ubers-payments-platform` and `protecting-against-retry-storms`. The rest are
identified but unread.

| Slug | Subject |
|---|---|
| `h3` | Hexagonal hierarchical geospatial index |
| `deepeta-how-uber-predicts-arrival-times` | ETA prediction service |
| `engineering-routing-engine` | Routing engine |
| `beacon-improving-pickups-with-better-location-accuracy` | Pickup location accuracy |
| `go-geofence-highest-query-per-second-service` | Geofence service in Go |
| `real-time-push-platform` | Push notification platform |
| `how-uber-optimizes-push-notifications-using-ml` | ML-ranked push |
| `building-scalable-real-time-chat` | In-app real-time chat |
| `schemaless-part-one-mysql-datastore` | Schemaless datastore |
| `schemaless-part-two-architecture` | Schemaless architecture |
| `schemaless-part-three-datastore-triggers` | Schemaless triggers |
| `schemaless-rewrite` | Schemaless rewrite |
| `ringpop-open-source-nodejs-library` | Gossip membership |
| `cadence-multi-tenant-task-processing` | Workflow orchestration |
| `m3` | Metrics platform |
| `michelangelo-machine-learning-platform` | ML platform |
| `scaling-michelangelo` | ML platform scaling |
| `simulated-marketplace` | Marketplace simulation |
| `reinforcement-learning-for-modeling-marketplace-balance` | Marketplace balance RL |
| `ubers-payments-platform` | Payments platform |
| `unified-checkout` | Unified checkout |
| `how-uber-processes-early-chargeback-signals` | Chargebacks |
| `how-uber-serves-over-150-million-reads` | Integrated cache |
| `protecting-against-retry-storms` | Retry storms |
| `scaling-api-gateway` | API gateway |
| `better-load-balancing-real-time-dynamic-subsetting` | Dynamic load balancing |
| `real-time-id-check` | Identity verification |
| `ubers-real-time-document-check` | Document checks |
| `trip-data-squeeze-json-encoding-compression` | Mobile payload compression |
| `how-uber-deals-with-large-ios-app-size` | Mobile app size |
| `solving-the-agent-identity-crisis` | Agent identity / Zero Trust |

<!-- END -->
