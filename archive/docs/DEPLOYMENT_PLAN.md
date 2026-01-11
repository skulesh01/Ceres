# 🚀 CERES v3.0.0 - PLAN РАЗВЁРТЫВАНИЯ ПОСЛЕ ТЕСТИРОВАНИЯ

## СТАТУС: ✅ ВСЕ ТЕСТЫ ПРОЙДЕНЫ - ГОТОВО К DEVELOPMENT

---

## PHASE 0: PRE-DEPLOYMENT (1-2 дня)

### Checklist
- [ ] Получить финальное approval от management
- [ ] Provisionировать staging окружение
- [ ] Создать backup стратегию для production
- [ ] Установить мониторинг и alerting
- [ ] Подготовить rollback процедуры
- [ ] Провести финальный security scan

### Команды

```bash
# 1. Verify all tests still pass
cd /path/to/ceres
bash tests/verify_tests.sh

# 2. Create backup
bash scripts/backup.sh --full --destination s3://backups/ceres-v3.0.0-backup

# 3. Setup monitoring
kubectl apply -f config/monitoring/prometheus-setup.yml
kubectl apply -f config/monitoring/grafana-setup.yml
kubectl apply -f config/monitoring/loki-setup.yml
```

---

## PHASE 1: STAGING DEPLOYMENT (4 часа)

### Задачи

1. **Развернуть Istio**
   ```bash
   kubectl apply -f config/istio/istio-install.yml
   
   # Wait for Istio to be ready
   kubectl wait --for=condition=Available --timeout=300s \
     deployment/istiod -n istio-system
   ```

2. **Развернуть Cost Optimization Suite**
   ```bash
   # Install cost optimization components
   kubectl apply -f config/cost/cost-suite.yml
   
   # Verify metrics collection
   kubectl port-forward -n monitoring svc/prometheus 9090:9090
   # Visit http://localhost:9090 and check for cost metrics
   ```

3. **Развернуть Terraform Infrastructure**
   ```bash
   cd terraform/
   terraform plan -out=tfplan
   terraform apply tfplan
   
   # Verify AWS/Azure/GCP resources
   aws eks describe-clusters
   az aks list
   gcloud container clusters list
   ```

4. **Применить Security Policies**
   ```bash
   kubectl apply -f config/security/hardening-policies.yml
   
   # Verify policies are enforced
   kubectl get psp
   kubectl get networkpolicies -A
   kubectl auth can-i get pods --namespace default --as system:unauthenticated
   ```

### Validation

```bash
# Run smoke tests
bash tests/test_integration.sh

# Check all components are ready
kubectl get deployments -A | grep ceres
kubectl get services -A | grep ceres

# Monitor logs
kubectl logs -f -l app=ceres-cost-suite -n kube-system
```

---

## PHASE 2: PILOT MIGRATION (1-2 дня)

### Target: 10% пользователей или 1-2 critical сервиса

### Pre-Migration

```bash
# 1. Backup existing data
kubectl exec -it deployment/postgres-main -- \
  pg_dump -U postgres ceres_db > ceres_db_backup_$(date +%Y%m%d).sql

# 2. Export secrets
kubectl get secrets -n ceres-system -o yaml > secrets_backup.yml

# 3. Verify prerequisites
bash tests/test_e2e_migration.sh
```

### Migration Steps

```bash
# 1. Enable Istio sidecar injection for pilot namespace
kubectl label namespace pilot-apps istio-injection=enabled

# 2. Deploy Istio proxies (rolling update)
kubectl rollout restart deployment -n pilot-apps
kubectl rollout status deployment -n pilot-apps

# 3. Gradually shift traffic to Istio
kubectl apply -f config/istio/virtual-services-pilot.yml
# Initial: 10% traffic to v3.0.0
# Monitor for 6 hours
# Increase to 25%
# Monitor for 6 hours
# Increase to 50% (canary complete if successful)

# 4. Monitor metrics
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Login and check: request latency, error rate, cost savings

# 5. Collect feedback
# Interview pilot users about performance, stability, issues
```

### Validation

```bash
# Performance metrics
kubectl top nodes
kubectl top pods -A

# Cost analysis
bash scripts/cost-optimization.sh --report

# Error rates (should be < 0.1%)
kubectl logs -l app=ceres --tail=1000 | grep ERROR | wc -l

# Latency
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Check: p99 latency < 200ms, p95 < 100ms
```

### Decision: Proceed or Rollback?

```bash
# If SUCCESS (< 0.1% errors, latency good, cost savings confirmed):
echo "✓ Pilot phase successful - proceed to Phase 3"

# If ISSUES:
# 1. Identify root cause
# 2. Fix in staging
# 3. Re-test
# 4. OR rollback to v2.9
bash scripts/rollback-cluster.sh --target v2.9
```

---

## PHASE 3: STAGED ROLLOUT (3-5 дней)

### Day 1: Non-Critical Services (30% users)

```bash
# Label non-critical namespaces
kubectl label namespace non-critical migration-wave=1

# Enable Istio injection
kubectl label namespace non-critical istio-injection=enabled

# Gradual traffic shift
for pct in 10 25 50 75 100; do
  kubectl patch virtualservice services -p \
    "{\"spec\":{\"hosts\":[{\"weight\": $pct, \"destination\":{\"host\":\"v3.0.0\"}}]}}"
  sleep $((6 * 60))  # Wait 6 hours
  bash scripts/health-check.sh
done
```

### Day 2-3: Important Services (40% users)

```bash
# Repeat for important namespaces
kubectl label namespace important-apps migration-wave=2
kubectl label namespace important-apps istio-injection=enabled

# Same gradual traffic shift
```

### Day 4-5: Critical Services (30% users)

```bash
# Careful rollout for critical services with highest monitoring
kubectl label namespace critical migration-wave=3
kubectl label namespace critical istio-injection=enabled

# Enhanced monitoring
kubectl apply -f config/monitoring/critical-apps-dashboard.yml

# Extra validation checkpoints
```

### Continuous Monitoring

```bash
# Every hour check:
bash scripts/health-check.sh
bash scripts/cost-optimization.sh --report
kubectl logs -l app=ceres --since=1h | grep ERROR

# Alert on anomalies
# - Error rate > 0.5%
# - p99 latency > 500ms
# - Cost increase > 5%
```

---

## PHASE 4: COMPLETE CUTOVER (1 день)

### Prerequisites
- All phases completed successfully
- No critical issues in logs
- Cost savings confirmed (target: 20-30%)
- User feedback positive

### Final Steps

```bash
# 1. Scale down v2.9
kubectl scale deployment ceres-v2.9 --replicas=0 -n production

# 2. Clean up old resources
kubectl delete pvc -l version=v2.9
kubectl delete configmap -l version=v2.9

# 3. Update DNS/load balancer to point only to v3.0.0
kubectl patch service ceres-ingress \
  -p '{"spec":{"selector":{"version":"v3.0.0"}}}'

# 4. Archive v2.9 configuration
tar czf ceres-v2.9-archive-$(date +%Y%m%d).tar.gz \
  config/v2.9/ scripts/v2.9/ docs/v2.9/
```

### Final Validation

```bash
# Run full test suite one more time
bash tests/run_tests.sh

# Monitor for 24 hours
for i in {1..24}; do
  echo "=== Hour $i ==="
  bash scripts/health-check.sh
  bash scripts/cost-optimization.sh --report
  sleep 1h
done
```

---

## PHASE 5: POST-DEPLOYMENT (1 неделя)

### Monitoring & Optimization

```bash
# Daily reports
0 9 * * * bash scripts/daily-report.sh | mail -s "CERES Daily Report" ops@ceres.local

# Weekly optimization
0 10 * * MON bash scripts/cost-optimization.sh --optimize

# Performance analysis
0 0 * * * bash scripts/performance-report.sh
```

### Documentation

```bash
# Update runbooks
vim docs/operations/RUNBOOK.md
# Add v3.0.0 specific procedures

# Update troubleshooting
vim docs/operations/TROUBLESHOOTING.md
# Document known issues and solutions

# Record lessons learned
vim docs/operations/LESSONS_LEARNED.md
```

### Team Training

- [ ] DevOps team training on v3.0.0
- [ ] SRE on-call training
- [ ] Support team incident response
- [ ] Management on cost savings

---

## ROLLBACK PROCEDURES

### Quick Rollback (< 30 minutes)

```bash
#!/bin/bash
# rollback-to-v2.9.sh

echo "Rolling back to CERES v2.9..."

# 1. Restore previous version deployments
kubectl set image deployment/ceres ceres=ceres:v2.9

# 2. Switch traffic back
kubectl apply -f config/istio/virtual-services-v2.9.yml

# 3. Wait for stability
kubectl rollout status deployment/ceres

# 4. Verify
bash scripts/health-check.sh

echo "Rollback complete!"
```

### Complete Rollback (if needed)

```bash
#!/bin/bash
# rollback-cluster.sh

# 1. Restore from backup
kubectl get pvc -o name | xargs -I {} kubectl delete {}
kubectl apply -f backups/pvc-restore-v2.9.yml

# 2. Restore secrets
kubectl delete secrets -A -l version=v3.0.0
kubectl apply -f backups/secrets-v2.9.yml

# 3. Restart services
kubectl rollout restart statefulset -A
kubectl rollout restart deployment -A

# 4. Monitor
for i in {1..10}; do
  bash scripts/health-check.sh
  sleep 1m
done
```

---

## COMMANDS QUICK REFERENCE

```bash
# Check deployment status
kubectl get deployments -A
kubectl get pods -A
kubectl get services -A

# View logs
kubectl logs -f -l app=ceres
kubectl logs -f deployment/ceres-cost-suite -n kube-system

# Monitor resources
kubectl top nodes
kubectl top pods -A

# Execute tests
bash tests/run_tests.sh
bash tests/test_integration.sh

# Cost analysis
bash scripts/cost-optimization.sh --report
bash scripts/cost-optimization.sh --optimize

# Health checks
bash scripts/health-check.sh
bash scripts/Test-Installation.ps1

# Database migration
bash scripts/migrate-database.sh --from v2.9 --to v3.0.0

# Backup/Restore
bash scripts/backup.sh --full
bash scripts/restore.sh --from backup.tar.gz
```

---

## MONITORING & ALERTS

### Key Metrics to Monitor

```
1. Availability
   - API response time (target: < 100ms p95)
   - Error rate (target: < 0.1%)
   - Pod restart count (target: 0)

2. Performance
   - CPU usage (target: < 70%)
   - Memory usage (target: < 75%)
   - Disk usage (target: < 80%)

3. Cost
   - Monthly spend (target: -20% vs v2.9)
   - Cost per request (target: -25%)
   - Reserved instance utilization (target: > 80%)

4. Security
   - Failed auth attempts (target: 0 abnormal spikes)
   - Network policy violations (target: 0)
   - Audit log entries (target: all critical events logged)
```

### Alert Rules

```yaml
# prometheus-rules.yml
groups:
  - name: ceres-v3-alerts
    rules:
      - alert: HighErrorRate
        expr: rate(errors_total[5m]) > 0.001
        for: 5m

      - alert: HighLatency
        expr: histogram_quantile(0.95, latency_seconds) > 0.1
        for: 5m

      - alert: CostAnomaly
        expr: increase(monthly_cost[1h]) > historical_average * 1.1
        for: 15m
```

---

## SUCCESS CRITERIA

✅ **Deployment Successful If:**

- [ ] All services running (100% uptime)
- [ ] Error rate < 0.1%
- [ ] Latency p95 < 100ms
- [ ] Cost reduction 20-30%
- [ ] All security policies enforced
- [ ] Zero data loss
- [ ] User satisfaction > 90%
- [ ] SLA met (99.9%)

---

## CONTACTS & ESCALATION

| Role | Name | Contact | On-Call |
|------|------|---------|---------|
| DevOps Lead | John Smith | john@ceres.local | Always |
| SRE Lead | Jane Doe | jane@ceres.local | Rotating |
| Security Lead | Bob Johnson | bob@ceres.local | As needed |
| Manager | Alice Brown | alice@ceres.local | Business hours |

---

## APPENDIX: CONFIGURATION FILES

```
Required files for deployment:

Core:
  - config/istio/istio-install.yml
  - config/terraform/multi-cloud.tf
  - config/security/hardening-policies.yml

Monitoring:
  - config/monitoring/prometheus-setup.yml
  - config/monitoring/grafana-dashboards.yml
  - config/monitoring/loki-config.yml

Backup/Restore:
  - scripts/backup.sh
  - scripts/restore.sh
  - scripts/rollback-cluster.sh

Testing:
  - tests/run_tests.sh
  - tests/test_integration.sh
  - tests/test_e2e_migration.sh
```

---

*Deployment Guide v1.0 | Updated: 2024-01-15*
