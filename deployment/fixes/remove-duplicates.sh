#!/bin/bash
# CERES v3.1 - Задача 1.1: Удаление дубликатов
# Удаляет 5 namespace с дублирующими сервисами

echo "🗑️  Удаление дубликатов..."
echo ""

# 1. Elasticsearch (дублирует Loki)
echo "1/5 Удаление Elasticsearch..."
kubectl delete namespace elasticsearch --ignore-not-found=true

# 2. Kibana (дублирует Loki UI)
echo "2/5 Удаление Kibana..."
kubectl delete namespace kibana --ignore-not-found=true

# 3. Harbor (дублирует GitLab Registry)
echo "3/5 Удаление Harbor..."
kubectl delete namespace harbor --ignore-not-found=true

# 4. Jenkins (дублирует GitLab CI)
echo "4/5 Удаление Jenkins..."
kubectl delete namespace jenkins --ignore-not-found=true

# 5. Uptime Kuma (дублирует Prometheus)
echo "5/5 Удаление Uptime Kuma..."
kubectl delete namespace uptime-kuma --ignore-not-found=true

echo ""
echo "✅ Дубликаты удалены!"
echo "💾 Освобождено ~4-6GB RAM"
