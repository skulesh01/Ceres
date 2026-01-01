#!/bin/bash
# StatefulSet конфигурации для PostgreSQL и Redis
# Развертывание на Kubernetes с persistent storage и HA

cat > /tmp/statefulset-postgres.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: ceres
  labels:
    app: postgres
    version: "15"
spec:
  serviceName: postgres-headless
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
        version: "15"
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - postgres
            topologyKey: kubernetes.io/hostname
      containers:
      - name: postgres
        image: postgres:15-alpine
        imagePullPolicy: IfNotPresent
        ports:
        - name: postgresql
          containerPort: 5432
          protocol: TCP
        env:
        - name: POSTGRES_DB
          value: ceres_db
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql
          readOnly: true
        - name: init-scripts
          mountPath: /docker-entrypoint-initdb.d
          readOnly: true
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 5
          failureThreshold: 2
        resources:
          requests:
            cpu: "2"
            memory: 4Gi
          limits:
            cpu: "4"
            memory: 8Gi
      volumes:
      - name: postgres-config
        configMap:
          name: postgres-config
      - name: init-scripts
        configMap:
          name: postgres-init-scripts
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
      labels:
        app: postgres
    spec:
      accessModes:
      - ReadWriteOnce
      storageClassName: ceres-database
      resources:
        requests:
          storage: 100Gi

---
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
  namespace: ceres
  labels:
    app: postgres
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
  - name: postgresql
    port: 5432
    targetPort: postgresql
    protocol: TCP

---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: ceres
  labels:
    app: postgres
spec:
  type: ClusterIP
  selector:
    app: postgres
  ports:
  - name: postgresql
    port: 5432
    targetPort: postgresql
    protocol: TCP

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: ceres
  labels:
    app: redis
    version: "7"
spec:
  serviceName: redis-headless
  replicas: 3
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        version: "7"
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - redis
            topologyKey: kubernetes.io/hostname
      containers:
      - name: redis
        image: redis:7-alpine
        imagePullPolicy: IfNotPresent
        command:
        - redis-server
        - /usr/local/etc/redis/redis.conf
        ports:
        - name: redis
          containerPort: 6379
          protocol: TCP
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: password
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        volumeMounts:
        - name: redis-storage
          mountPath: /data
        - name: redis-config
          mountPath: /usr/local/etc/redis
          readOnly: true
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 5
          failureThreshold: 2
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: "1"
            memory: 2Gi
      volumes:
      - name: redis-config
        configMap:
          name: redis-config
  volumeClaimTemplates:
  - metadata:
      name: redis-storage
      labels:
        app: redis
    spec:
      accessModes:
      - ReadWriteOnce
      storageClassName: ceres-cache
      resources:
        requests:
          storage: 50Gi

---
apiVersion: v1
kind: Service
metadata:
  name: redis-headless
  namespace: ceres
  labels:
    app: redis
spec:
  clusterIP: None
  selector:
    app: redis
  ports:
  - name: redis
    port: 6379
    targetPort: redis
    protocol: TCP

---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: ceres
  labels:
    app: redis
spec:
  type: ClusterIP
  selector:
    app: redis
  ports:
  - name: redis
    port: 6379
    targetPort: redis
    protocol: TCP
EOF

echo "StatefulSet конфигурация готова!"
echo "Применить: kubectl apply -f /tmp/statefulset-postgres.yml"
