# CERES High Availability & Load Balancing Guide

**Version:** 2.5.0 | **Last Updated:** January 2026

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Components](#components)
4. [Quick Start](#quick-start)
5. [PostgreSQL HA with Patroni](#postgresql-ha-with-patroni)
6. [Redis HA with Sentinel](#redis-ha-with-sentinel)
7. [Load Balancing with HAProxy](#load-balancing-with-haproxy)
8. [Failover & Recovery](#failover--recovery)
9. [Monitoring & Observability](#monitoring--observability)
10. [Troubleshooting](#troubleshooting)
11. [Best Practices](#best-practices)

---

## Overview

This guide covers the High Availability (HA) and Load Balancing layer of CERES v2.5.0, which transforms the platform from a single-point-of-failure 3-VM architecture into a resilient, fault-tolerant distributed system.

### Key Objectives

- **Zero Downtime:** Automatic failover without manual intervention
- **Data Consistency:** Synchronous replication ensures no data loss
- **Load Distribution:** Request routing across healthy nodes
- **Visibility:** Real-time health monitoring and metrics
- **Simple Recovery:** Automatic node recovery and rejoining

### Why HA Matters

- **99.9% Availability:** Tolerate single node failures
- **Automatic Failover:** No manual intervention needed
- **Data Protection:** Synchronous replication prevents data loss
- **Scalability:** Easy to add capacity without downtime
- **Compliance:** Meet SLA requirements for enterprise customers

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     CLIENT APPLICATIONS                      │
└──────────────────────────┬──────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
    ┌───▼───┐         ┌───▼───┐        ┌────▼────┐
    │ HAProxy│         │HAProxy│        │HAProxy  │
    │  Port  │         │ Port  │        │ Port    │
    │80/443  │         │80/443 │        │80/443   │
    └───┬───┘         └───┬───┘        └────┬────┘
        │                  │                  │
   ┌────┴─────────────────┼──────────────────┴────┐
   │                      │                       │
┌──▼──────┐          ┌────▼────┐         ┌───────▼───┐
│PostgreSQL  Patroni │PostgreSQL  Patroni│PostgreSQL   Patroni│
│Node 1      Managed │Node 2      Managed│Node 3       Managed│
│Primary    Failover │Secondary  Failover│Secondary   Failover│
└──────────┘        └──────────┘        └──────────┘
   │                      │                  │
   └──────────┬───────────┴──────────────────┘
              │
         ┌────▼─────┐
         │etcd Cluster│ (DCS)
         │Discovery   │
         │& Config    │
         └────────────┘

┌────────────────────────────────────────────────────┐
│    Redis HA Cluster (Master-Replica Pattern)      │
├────────────────────────────────────────────────────┤
│                                                    │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐   │
│  │Redis-1  │    │Redis-2  │    │Redis-3  │   │
│  │MASTER   │───▶│REPLICA  │───▶│REPLICA  │   │
│  │Port6379 │    │Port6380 │    │Port6381 │   │
│  └────┬─────┘    └────┬─────┘    └────┬────┘   │
│       │               │               │        │
│  ┌────▼──────────────▼───────────────▼────┐   │
│  │   Redis Sentinel (3 instances)        │   │
│  │  - Monitors master health             │   │
│  │  - Triggers automatic failover        │   │
│  │  - Maintains replica configuration    │   │
│  └───────────────────────────────────────┘   │
│                                                │
└────────────────────────────────────────────────┘
```

### Failure Scenarios Handled

1. **PostgreSQL Primary Down:** Patroni promotes secondary automatically
2. **Redis Master Down:** Sentinel promotes best replica automatically
3. **Network Partition:** etcd quorum determines action
4. **Complete Data Center Down:** DNS failover to backup region
5. **Cascading Failures:** Health checks prevent split brain

---

## Components

### Patroni (PostgreSQL HA)

Patroni is a distributed configuration management tool that ensures PostgreSQL clusters maintain high availability.

**Features:**
- Automatic leader election via etcd
- Synchronous replication with quorum
- Self-healing member management
- Zero-copy replication streaming
- Smart health checks
- REST API for monitoring

**Default Configuration:**
- 3 PostgreSQL nodes
- Synchronous mode (strict)
- 30-second failover TTL
- 10-second loop wait (health check interval)

### Redis Sentinel

Redis Sentinel provides monitoring, notification, and failover for Redis instances.

**Features:**
- Automatic failover with configurable downtime
- Sentinel quorum (3 instances minimum)
- Configuration propagation
- Notification webhooks
- Memory-efficient monitoring

**Default Configuration:**
- 3 Redis Sentinel instances
- 5-second downtime threshold
- 2-quorum requirement
- 30-second failover timeout

### HAProxy

HAProxy provides layer 4 and 7 load balancing with health checks.

**Features:**
- TCP load balancing (PostgreSQL, Redis)
- HTTP load balancing (Applications)
- Health-based routing
- Sticky sessions support
- SSL/TLS termination
- Real-time stats dashboard

**Default Configuration:**
- Port 80/443 for HTTP/HTTPS
- Port 5432 for PostgreSQL
- Port 6379 for Redis
- Health checks every 10 seconds

### etcd (Distributed Configuration Store)

etcd stores PostgreSQL cluster state and enables Patroni members to coordinate.

**Characteristics:**
- Strongly consistent
- Distributed consensus (Raft)
- Watch-based notifications
- TTL support
- Transaction support

---

## Quick Start

### 1. Prepare Environment

Create `.env` file with required variables:

```bash
# Database credentials
POSTGRES_PASSWORD=your-secure-password-here
POSTGRES_USER=postgres

# Redis credentials
REDIS_PASSWORD=your-redis-password-here
REDIS_SENTINEL_PASSWORD=your-sentinel-password-here

# Domain configuration
DOMAIN_NAME=your.domain.com

# Optional: HAProxy stats
HAPROXY_STATS_ENABLED=true
HAPROXY_STATS_URI=/stats
```

### 2. Run Setup Script

```bash
# Linux/Mac
chmod +x scripts/setup-ha.sh
./scripts/setup-ha.sh

# Windows PowerShell
.\scripts\setup-ha.ps1
```

### 3. Verify Cluster

```bash
# Monitor cluster health
./scripts/monitor-ha-health.sh

# Check PostgreSQL primary
docker exec ceres-postgres-1 pg_isready -U postgres

# Check Redis master
docker exec ceres-redis-1 redis-cli ping

# View HAProxy stats
curl http://localhost:8404/stats
```

### 4. Update Application Connections

Replace direct service connections with HA endpoints:

```python
# Old: Direct connection
db_conn = psycopg2.connect(
    host="postgres",
    port=5432,
    database="ceres"
)

# New: HAProxy load balanced
db_conn = psycopg2.connect(
    host="haproxy",
    port=5432,
    database="ceres"
)

# With connection pooling (recommended)
from psycopg2 import pool
db_pool = pool.SimpleConnectionPool(
    1, 20,
    host="haproxy",
    port=5432,
    database="ceres"
)
```

---

## PostgreSQL HA with Patroni

### Understanding Patroni

Patroni is a template for high availability in PostgreSQL using Python and etcd.

```yaml
# Key configuration parameters
scope: ceres-pg-cluster           # Cluster identifier
etcd:
  ttl: 30                         # Time-to-live for leases
  loop_wait: 10                   # Health check interval
  synchronous_mode: true          # Require quorum for commits
  synchronous_mode_strict: true   # Strict quorum enforcement
```

### Cluster Topology

```
Node 1 (postgres-1): PRIMARY
  - Accepts writes
  - Streams WAL to replicas
  - Port 5432

Node 2 (postgres-2): SECONDARY (hot standby)
  - Can accept reads
  - Receives WAL stream
  - Port 5433

Node 3 (postgres-3): SECONDARY (hot standby)
  - Can accept reads
  - Receives WAL stream
  - Port 5434
```

### Replication Details

**Synchronous Replication Setup:**

```sql
-- View current replication status
SELECT * FROM pg_stat_replication;

-- View synchronous replication status
SHOW synchronous_standby_names;

-- View standby clients
SELECT client_addr, state, write_lsn FROM pg_stat_replication;
```

**Replication Parameters:**

- `wal_level = replica` - Enable replication
- `max_wal_senders = 10` - Max concurrent replicas
- `synchronous_commit = remote_apply` - Wait for replica application
- `hot_standby = on` - Enable read queries on standby

### Failover Process

```
1. Primary Health Check Fails
   ↓
2. Patroni Detects Failure (within 10 seconds)
   ↓
3. etcd Consensus on New Primary
   ↓
4. Best Secondary Promoted to Primary (pg_ctl promote)
   ↓
5. Other Secondaries Reattach (recovery.conf updated)
   ↓
6. DNS/HAProxy Routes Traffic to New Primary
   ↓
Total Time: ~20-30 seconds
```

### Monitoring Patroni

```bash
# Check Patroni REST API
curl http://localhost:8008

# JSON format
curl -s http://postgres-1:8008 | jq .

# Get cluster members
curl -s http://postgres-1:8008/cluster | jq .members

# Manual failover (use with caution)
curl -X POST http://postgres-1:8008/failover
```

### Key PostgreSQL Queries

```sql
-- Check replication lag
SELECT 
  client_addr,
  state,
  write_lag,
  flush_lag,
  replay_lag
FROM pg_stat_replication;

-- Check archive status
SELECT * FROM pg_stat_archiver;

-- Monitor transaction ID consumption
SELECT 
  datname,
  age(datfrozenxid) as age
FROM pg_database;

-- Check WAL consumption
SELECT 
  wal_name,
  size
FROM pg_ls_waldir()
ORDER BY modification DESC LIMIT 10;
```

---

## Redis HA with Sentinel

### Sentinel Architecture

Redis Sentinel monitors Redis instances and performs automatic failover.

```
Sentinel 1  ←→  Sentinel 2  ←→  Sentinel 3
   (26379)         (26380)        (26381)
     ↓              ↓               ↓
    Monitors Master Health (redis-1:6379)
     ↓              ↓               ↓
  Redis Master   Redis Replica   Redis Replica
   (6379)         (6380)          (6381)
```

### Sentinel Configuration

```conf
# Monitored set name
sentinel monitor ceres-redis-cluster redis-1 6379 2

# Downtime before failover
sentinel down-after-milliseconds ceres-redis-cluster 5000

# Parallel syncs during failover
sentinel parallel-syncs ceres-redis-cluster 1

# Failover timeout
sentinel failover-timeout ceres-redis-cluster 30000
```

### Replication Setup

```bash
# Master (Redis 1)
redis-cli -h redis-1 -p 6379 -a PASSWORD
> ROLE
master
> CLIENT LIST

# Replica (Redis 2)
redis-cli -h redis-2 -p 6380 -a PASSWORD
> ROLE
slave redis-1 6379 connected
> INFO REPLICATION
role:slave
master_host:redis-1
master_port:6379
master_link_status:up
```

### Failover Behavior

```
1. Sentinel detects master down (5 seconds)
   ↓
2. Multiple sentinels agree (quorum = 2)
   ↓
3. Best replica selected (replication offset)
   ↓
4. Replica promoted to master (SLAVEOF NO ONE)
   ↓
5. Other replicas reconfigure (SLAVEOF new-master)
   ↓
6. Clients retry connections
   ↓
Total Time: ~5-10 seconds
```

### Monitoring Sentinel

```bash
# Connect to sentinel
redis-cli -p 26379 -a SENTINEL_PASSWORD

# List monitored masters
SENTINEL MASTERS

# Get master info
SENTINEL MASTER ceres-redis-cluster

# Get replica info
SENTINEL REPLICAS ceres-redis-cluster

# Get sentinel info
SENTINEL SENTINELS ceres-redis-cluster

# Trigger manual failover (testing only)
SENTINEL FAILOVER ceres-redis-cluster
```

### Client Connection Strategies

**Strategy 1: Sentinel Discovery (Recommended)**
```python
from redis.sentinel import Sentinel

sentinel = Sentinel([
    ('redis-sentinel-1', 26379),
    ('redis-sentinel-2', 26380),
    ('redis-sentinel-3', 26381)
], socket_connect_timeout=0.1, password='sentinel-password')

master = sentinel.master_for('ceres-redis-cluster', 
                            socket_connect_timeout=0.1,
                            password='redis-password')
master.set('key', 'value')
```

**Strategy 2: HAProxy Connection (Simpler)**
```python
import redis

r = redis.Redis(
    host='haproxy',
    port=6379,
    password='redis-password',
    decode_responses=True
)
```

---

## Load Balancing with HAProxy

### HAProxy Topology

```
Internet
   ↓
Ports 80/443 (HTTP/HTTPS)
   ↓
HAProxy (Load Balancer)
   ├─→ Nextcloud backend (3 instances, RR)
   ├─→ Gitea backend (3 instances, RR)
   ├─→ Mattermost backend (3 instances, RR)
   ├─→ Redmine backend (3 instances, RR)
   ├─→ Wiki.js backend (3 instances, RR)
   ├─→ PostgreSQL (3 Patroni nodes, sticky)
   └─→ Redis (3 Sentinel nodes, sticky)
```

### Configuration Highlights

```haproxy
# Frontend for HTTP/HTTPS
frontend http_front
  bind *:80
  bind *:443 ssl
  mode http
  
  # ACL rules for routing
  acl is_nextcloud hdr(host) -i nextcloud.domain.com
  acl is_gitea hdr(host) -i gitea.domain.com
  
  # Route based on hostname
  use_backend nextcloud_backend if is_nextcloud
  use_backend gitea_backend if is_gitea

# Backend with health checks
backend nextcloud_backend
  balance roundrobin
  mode http
  option httpchk GET /status.php
  default-server inter 10s fall 3 rise 2
  server nextcloud1 nextcloud:80 check
```

### Health Check Endpoints

```
Service             Health Check Endpoint    Expected Status
─────────────────────────────────────────────────────────
Nextcloud          GET /status.php          200
Gitea              GET /api/healthz         200
Mattermost         GET /api/v4/system/health  200
Redmine            GET /                    200
Wiki.js            GET /health              200
Prometheus         GET /-/healthy           200
Grafana            GET /api/health          200
PostgreSQL (TCP)   Connect to :5432         Connected
Redis (TCP)        Connect to :6379         Connected
```

### Accessing Services

```bash
# Direct to HAProxy (recommended)
curl https://nextcloud.domain.com
redis-cli -h haproxy -p 6379
psql -h haproxy -U postgres -d ceres

# Direct to specific node (troubleshooting)
curl https://nextcloud:80        # Nextcloud node
redis-cli -h redis-1 -p 6379    # Redis node 1
psql -h postgres-2 -U postgres  # PostgreSQL node 2
```

### HAProxy Stats Dashboard

```
URL: http://localhost:8404/stats
Username: (depends on configuration)
Password: (depends on configuration)

Displays:
- Frontend/backend status
- Server health status
- Request counts
- Error rates
- Response times
- Session counts
```

### Advanced HAProxy Features

**Rate Limiting:**
```haproxy
stick-table type ip size 100k expire 30s store http_req_rate(10s)
http-request track-sc0 src
http-request deny if { sc_http_req_rate(0) gt 100 }
```

**Sticky Sessions:**
```haproxy
cookie SERVERID insert indirect nocache
server server1 localhost:8001 cookie server1
```

**SSL/TLS Configuration:**
```haproxy
bind *:443 ssl crt /etc/ssl/certs/haproxy.pem
tune.ssl.default-dh-param 2048
http-request set-header X-Forwarded-Proto https if { ssl_fc }
```

---

## Failover & Recovery

### PostgreSQL Failover Workflow

**Before Failover:**
- Primary: postgres-1 (accepts reads & writes)
- Replica 1: postgres-2 (read-only)
- Replica 2: postgres-3 (read-only)

**Failure Scenario:**
```
1. postgres-1 becomes unavailable
2. Patroni health check fails 2 consecutive times (20 seconds)
3. etcd quorum elects new primary
4. postgres-2 is promoted:
   - PostgreSQL receives SIGTERM for graceful shutdown
   - Kills existing connections
   - postgres_promote() function executed
   - Waits for WAL recovery
5. postgres-3 reattaches to postgres-2 as replica
6. Applications reconnect via HAProxy
```

**After Failover:**
- Primary: postgres-2 (was replica)
- Replica 1: postgres-3 (was replica)
- Replica 2: postgres-1 (rejoins after recovery)

### Redis Failover Workflow

**Before Failover:**
- Master: redis-1
- Replica 1: redis-2
- Replica 2: redis-3

**Failure Scenario:**
```
1. redis-1 becomes unavailable
2. Sentinels detect offline (5 seconds)
3. Sentinels reach consensus (2 of 3)
4. Sentinels select best replica:
   - redis-2: replication offset 50000
   - redis-3: replication offset 45000
   → redis-2 selected (higher offset = fewer lost commands)
5. redis-2 promoted:
   - SLAVEOF NO ONE
   - Accepts writes
6. redis-3 reattaches:
   - SLAVEOF redis-2 6379
7. Clients reconnected via Sentinel/HAProxy
```

**After Failover:**
- Master: redis-2
- Replica 1: redis-3
- Replica 2: redis-1 (rejoins after recovery)

### Recovery Procedures

**Recovering Failed PostgreSQL Node:**

```bash
# Check node status
docker exec ceres-postgres-2 pg_isready -U postgres

# View logs
docker logs ceres-postgres-2 | tail -100

# Restart node
docker restart ceres-postgres-2

# Monitor recovery
docker exec ceres-postgres-2 tail -f /var/log/postgresql/postgresql.log

# Verify replication
docker exec ceres-postgres-1 psql -U postgres -c \
  "SELECT client_addr, state FROM pg_stat_replication;"
```

**Recovering Failed Redis Node:**

```bash
# Check node status
docker exec ceres-redis-2 redis-cli ping

# View logs
docker logs ceres-redis-2 | tail -100

# Restart node
docker restart ceres-redis-2

# Verify replication
docker exec ceres-redis-2 redis-cli info replication

# Check sentinel status
docker exec ceres-redis-sentinel-1 \
  redis-cli -p 26379 sentinel slaves ceres-redis-cluster
```

### Split Brain Prevention

**Patroni Protection:**
- etcd quorum requirement (2 of 3)
- Strict synchronous mode
- TTL-based leader lease

**Sentinel Protection:**
- Quorum requirement (2 of 3 sentinels)
- Configuration epoch tracking
- Automatic configuration propagation

**Network-Level:**
- No network partition tolerance without quorum
- Smaller partition becomes read-only
- Automatic healing when partition heals

---

## Monitoring & Observability

### Key Metrics to Monitor

**PostgreSQL Metrics:**
```prometheus
# Replication lag (in bytes)
pg_stat_replication_write_lag_bytes
pg_stat_replication_flush_lag_bytes
pg_stat_replication_replay_lag_bytes

# Connection count
pg_stat_activity_count

# Transaction age
pg_database_xid_age

# Checkpoint duration
pg_stat_bgwriter_checkpoint_write_time_total
```

**Redis Metrics:**
```prometheus
# Memory usage
redis_memory_used_bytes

# Connected clients
redis_connected_clients

# Replicated bytes
redis_replication_repl_backlog_size

# Replication lag
redis_replication_repl_backlog_histlen
```

**HAProxy Metrics:**
```prometheus
# Frontend requests
haproxy_frontend_http_requests_total

# Backend server status
haproxy_backend_up

# Request duration
haproxy_backend_http_response_time_milliseconds

# Error rates
haproxy_frontend_http_responses_4xx_total
haproxy_frontend_http_responses_5xx_total
```

### Prometheus Recording Rules

```yaml
# Replication health
- record: pg:replication:lag_bytes
  expr: max(pg_stat_replication_write_lag_bytes) by (instance)

- record: pg:replication:unhealthy
  expr: count(pg_stat_replication) by (instance) < 1

# Redis sentinel health
- record: redis:sentinel:masters
  expr: count(redis_sentinel_master_ok_slaves) by (master)

- record: redis:sentinel:downtime
  expr: max(redis_sentinel_master_last_ok_sec) by (master)

# HAProxy availability
- record: haproxy:backend:availability
  expr: haproxy_backend_up / count(haproxy_backend_up) by (backend)

- record: haproxy:error:rate
  expr: rate(haproxy_frontend_http_responses_5xx_total[5m])
```

### Alerting Rules

```yaml
- alert: PostgreSQLReplicationLag
  expr: pg:replication:lag_bytes > 10485760  # 10MB
  for: 5m
  annotations:
    summary: "PostgreSQL replication lag > 10MB"

- alert: PostgreSQLReplicationDown
  expr: pg:replication:unhealthy
  for: 2m
  annotations:
    summary: "PostgreSQL replica connection lost"

- alert: RedisSentinelMasterDown
  expr: redis_sentinel_master_ok_slaves == 0
  for: 1m
  annotations:
    summary: "Redis master is down in sentinel monitoring"

- alert: HAProxyBackendDown
  expr: haproxy:backend:availability < 0.5
  for: 2m
  annotations:
    summary: "HAProxy backend availability < 50%"
```

---

## Troubleshooting

### Common Issues

**Issue: PostgreSQL Cluster Stuck**
```bash
# Check etcd status
docker exec ceres-etcd etcdctl member list

# Check Patroni logs
docker logs ceres-postgres-1 | grep -i error

# Reset Patroni (dangerous - last resort)
docker exec ceres-postgres-1 rm -rf /var/lib/postgresql/data
docker restart ceres-postgres-1
```

**Issue: Redis Sentinel Not Detecting Failover**
```bash
# Check sentinel logs
docker logs ceres-redis-sentinel-1

# Verify sentinel is monitoring
docker exec ceres-redis-sentinel-1 redis-cli -p 26379 \
  sentinel master ceres-redis-cluster

# Reset sentinel (last resort)
docker exec ceres-redis-sentinel-1 redis-cli -p 26379 \
  sentinel reset ceres-redis-cluster
```

**Issue: HAProxy Backend All Down**
```bash
# Check HAProxy config
docker exec ceres-haproxy haproxy -f /usr/local/etc/haproxy/haproxy.cfg -c

# Check backend connectivity
docker exec ceres-haproxy telnet nextcloud 80

# View HAProxy logs
docker logs ceres-haproxy | tail -50
```

**Issue: Connection Timeouts After Failover**
```bash
# Increase connection pool timeout
db_pool = pool.SimpleConnectionPool(
    1, 20,
    host="haproxy",
    port=5432,
    connect_timeout=10  # Increased from default 3
)

# Implement retry logic
import time
for attempt in range(3):
    try:
        connection = db_pool.getconn()
        break
    except Exception:
        if attempt < 2:
            time.sleep(2 ** attempt)
        else:
            raise
```

### Diagnostic Commands

```bash
# PostgreSQL cluster status
docker exec ceres-postgres-1 patronictl -c /etc/patroni/patroni.yml list

# Detailed node status
docker exec ceres-postgres-1 patronictl -c /etc/patroni/patroni.yml show-config

# etcd cluster status
docker exec ceres-etcd etcdctl --endpoints=http://localhost:2379 endpoint health

# Redis replication info
docker exec ceres-redis-1 redis-cli -a PASSWORD info replication

# HAProxy connection summary
docker exec ceres-haproxy netstat -an | grep ESTABLISHED | wc -l

# Network connectivity test
docker exec ceres-postgres-1 nc -zv postgres-2 5432
docker exec ceres-redis-1 nc -zv redis-2 6379
```

---

## Best Practices

### Operational Guidelines

1. **Always Test Failover Regularly**
   ```bash
   # Simulate postgres primary failure
   docker stop ceres-postgres-1
   
   # Monitor failover (should take < 30 seconds)
   watch -n 1 'docker exec ceres-postgres-2 pg_isready -U postgres'
   
   # Restart and observe recovery
   docker start ceres-postgres-1
   ```

2. **Monitor Replication Lag**
   ```
   Alert threshold: > 10 MB or > 5 seconds
   Action: Investigate network, disk I/O, CPU
   ```

3. **Plan for Maintenance**
   ```bash
   # Maintenance on secondary node
   docker restart ceres-postgres-2  # No impact on primary
   
   # Maintenance on primary - perform switchover
   docker exec ceres-postgres-1 patronictl switchover
   # This promotes secondary and demotes primary gracefully
   ```

4. **Backup Strategy**
   ```
   - WAL archiving to separate storage
   - Point-in-time recovery (PITR) setup
   - Regular full backup + incremental WALs
   - Test restore procedures quarterly
   ```

5. **Capacity Planning**
   ```
   - Monitor disk usage growth
   - Plan for ~30% headroom
   - Archive old WALs regularly
   - Monitor connection pool exhaustion
   ```

### Performance Optimization

**PostgreSQL Tuning:**
```sql
-- Check query performance
SELECT mean_exec_time, query FROM pg_stat_statements 
ORDER BY mean_exec_time DESC LIMIT 10;

-- Identify missing indexes
SELECT schemaname, tablename FROM pg_tables 
WHERE schemaname NOT IN ('pg_catalog', 'information_schema');

-- Check autovacuum activity
SELECT relname, last_vacuum, last_autovacuum FROM pg_stat_user_tables;
```

**Redis Optimization:**
```bash
# Monitor slow queries
redis-cli -a PASSWORD slowlog get 10

# Check eviction policy
redis-cli -a PASSWORD config get maxmemory-policy

# Memory analysis
redis-cli -a PASSWORD --bigkeys
redis-cli -a PASSWORD --memkeys
```

**HAProxy Optimization:**
```
- Adjust timeouts based on workload
- Implement connection pooling on client side
- Use persistent connections
- Monitor backend response times
- Consider connection limits per IP
```

### Security Considerations

1. **SSL/TLS Certificates**
   - Use CA-signed certificates in production
   - Rotate certificates every 12 months
   - Monitor certificate expiration

2. **Password Management**
   - Store passwords in secure vault (not .env)
   - Rotate passwords quarterly
   - Use complex passwords (32+ characters)
   - Implement rate limiting on failed attempts

3. **Network Segmentation**
   - Keep etcd on private network only
   - Restrict PostgreSQL access via HAProxy
   - Use network policies/firewalls
   - Monitor unusual connection patterns

4. **Audit Logging**
   - Enable PostgreSQL audit logging
   - Monitor Sentinel configuration changes
   - Review HAProxy access logs
   - Alert on authentication failures

---

## Integration with Application

### Django Configuration

```python
import os
from psycopg2 import pool

# Database connection pooling with HA
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'HOST': 'haproxy',
        'PORT': 5432,
        'NAME': 'ceres',
        'USER': 'postgres',
        'PASSWORD': os.getenv('POSTGRES_PASSWORD'),
        'CONN_MAX_AGE': 600,
        'OPTIONS': {
            'connect_timeout': 10,
        }
    }
}

# Cache configuration with Sentinel
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': 'redis://haproxy:6379/1',
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            'PARSER_KWARGS': {'decode_responses': True},
            'CONNECTION_POOL_KWARGS': {
                'password': os.getenv('REDIS_PASSWORD'),
                'health_check_interval': 30,
            }
        }
    }
}
```

### Flask Configuration

```python
import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
import redis

app = Flask(__name__)

# PostgreSQL with HA
app.config['SQLALCHEMY_DATABASE_URI'] = (
    f"postgresql+psycopg2://postgres:{os.getenv('POSTGRES_PASSWORD')}"
    f"@haproxy:5432/ceres"
)
app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
    'pool_size': 10,
    'pool_recycle': 3600,
    'pool_pre_ping': True,
}

db = SQLAlchemy(app)

# Redis with HA
redis_client = redis.Redis(
    host='haproxy',
    port=6379,
    password=os.getenv('REDIS_PASSWORD'),
    decode_responses=True,
    socket_keepalive=True,
    socket_keepalive_options={
        1: 1,  # TCP_KEEPIDLE
        2: 1,  # TCP_KEEPINTVL
        3: 3,  # TCP_KEEPCNT
    }
)
```

---

## Maintenance & Upgrade

### Rolling Upgrade Procedure

```bash
# 1. Start with replica
docker-compose -f config/compose/ha.yml up -d --no-deps postgres-2
# Wait for recovery
sleep 30

# 2. Upgrade second replica
docker-compose -f config/compose/ha.yml pull postgres-3
docker-compose -f config/compose/ha.yml up -d postgres-3 --no-deps
sleep 30

# 3. Switch primary to secondary (graceful switchover)
docker exec ceres-postgres-1 patronictl switchover
# Waits for promotion, typically 10-20 seconds

# 4. Upgrade old primary (now secondary)
docker-compose -f config/compose/ha.yml pull postgres-1
docker-compose -f config/compose/ha.yml up -d postgres-1 --no-deps
sleep 30

# 5. Verify all nodes healthy
./scripts/monitor-ha-health.sh
```

### Backup & Recovery

```bash
# Continuous WAL archiving
pg_basebackup -h haproxy -D /backups/pg-base -Ft -z -P

# PITR restore
pg_ctl -D /recovery_data initdb --allow-group-access
cp /backups/pg-base.tar.gz /recovery_data/
tar -xzf /recovery_data/pg-base.tar.gz -C /recovery_data/
# ... set recovery_target_timeline = 'latest' ...
pg_ctl -D /recovery_data start
```

---

## Conclusion

The CERES High Availability & Load Balancing layer provides enterprise-grade resilience with:

✅ **Automatic Failover** - No manual intervention needed
✅ **Zero Data Loss** - Synchronous replication ensures consistency
✅ **Transparent to Applications** - HAProxy handles routing
✅ **Monitoring Built-In** - Real-time health checks and metrics
✅ **Easy Recovery** - Self-healing cluster members
✅ **Enterprise Ready** - Meets 99.9% uptime requirements

With v2.5.0, CERES is now production-ready for mission-critical deployments.
