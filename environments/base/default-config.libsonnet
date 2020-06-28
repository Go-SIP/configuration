{
  local defaultConfig = self,

  name: 'observatorium-xyz',
  namespace: 'observatorium',
  thanosVersion: 'master-2020-05-24-079ad427',  // Fixes a blocker issue in v0.13.0-rc.0
  thanosImage: 'quay.io/thanos/thanos:' + defaultConfig.thanosVersion,
  objectStorageConfig: {
    thanos: {
      name: 'thanos-objectstorage',
      key: 'thanos.yaml',
    },
    loki: {
      name: 'loki-objectstorage',
      key: 'endpoint',
    },
  },

  hashrings: [
    {
      hashring: 'default',
      tenants: [
        // Match all for now
        // 'foo',
        // 'bar',
      ],
    },
  ],

  compact: {
    image: defaultConfig.thanosImage,
    version: defaultConfig.thanosVersion,
    objectStorageConfig: defaultConfig.objectStorageConfig.thanos,
    retentionResolutionRaw: '14d',
    retentionResolution5m: '1s',
    retentionResolution1h: '1s',
    volumeClaimTemplate: {
      spec: {
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: '50Gi',
          },
        },
      },
    },
  },

  thanosReceiveController: {
    local trcConfig = self,
    version: 'master-2020-02-06-b66e0c8',
    image: 'quay.io/observatorium/thanos-receive-controller:' + trcConfig.version,
    hashrings: defaultConfig.hashrings,
  },

  receivers: {
    image: defaultConfig.thanosImage,
    version: defaultConfig.thanosVersion,
    hashrings: defaultConfig.hashrings,
    objectStorageConfig: defaultConfig.objectStorageConfig.thanos,
    volumeClaimTemplate: {
      spec: {
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: '50Gi',
          },
        },
      },
    },
    logLevel: 'info',
    debug: '',
  },

  rule: {
    image: defaultConfig.thanosImage,
    version: defaultConfig.thanosVersion,
    objectStorageConfig: defaultConfig.objectStorageConfig.thanos,
    volumeClaimTemplate: {
      spec: {
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: '50Gi',
          },
        },
      },
    },
  },

  store: {
    image: defaultConfig.thanosImage,
    version: defaultConfig.thanosVersion,
    objectStorageConfig: defaultConfig.objectStorageConfig.thanos,
    shards: 1,
    volumeClaimTemplate: {
      spec: {
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: '50Gi',
          },
        },
      },
    },
  },

  storeCache: {
    local scConfig = self,
    replicas: 1,
    version: '1.6.3-alpine',
    image: 'docker.io/memcached:' + scConfig.version,
    exporterVersion: 'v0.6.0',
    exporterImage: 'prom/memcached-exporter:' + scConfig.exporterVersion,
    memoryLimitMb: 1024,
  },

  query: {
    image: defaultConfig.thanosImage,
    version: defaultConfig.thanosVersion,
  },

  queryCache: {
    local qcConfig = self,
    replicas: 1,
    version: 'master-fdcd992f',
    image: 'quay.io/cortexproject/cortex:' + qcConfig.version,
  },

  api: {
    local apiConfig = self,
    version: 'master-2020-06-26-v0.1.1-105-gc784d77',
    image: 'quay.io/observatorium/observatorium:' + apiConfig.version,
  },

  withTLS: {
    local apiWithTLS = self,
    serverPem: 'server.pem',
    serverKey: 'server.key',
    volumeMounts: {
      name: 'observatorium-api-tls-certs',
      secretName: 'observatorium-api-tls-certs',
      mountPath: '/mnt/certs',
      readOnly: true,
    },
    certFile: apiWithTLS.volumeMounts.mountPath + apiWithTLS.serverPem,
    privateKeyFile: apiWithTLS.volumeMounts.mountPath + apiWithTLS.serverKey,
    reloadInterval: '1m',
  },

  withMTLS: {
    local apiWithMTLS = self,
    caPem: 'ca.pem',
    volumeMounts: {
      name: 'observatorium-api-tls-client-ca',
      mountPath: '/mnt/clientca',
      readOnly: true,
    },
    clientCAFile: apiWithMTLS.volumeMounts.mountPath + apiWithMTLS.caPem,
  },

  apiQuery: {
    image: defaultConfig.thanosImage,
    version: defaultConfig.thanosVersion,
  },

  up: {
    local upConfig = self,
    version: 'master-2020-06-03-8a20b4e',
    image: 'quay.io/observatorium/up:' + upConfig.version,
  },

  lokiRingStore: {
    local lokiRingStoreConfig = self,
    version: 'v3.4.9',
    image: 'quay.io/coreos/etcd:' + lokiRingStoreConfig.version,
    replicas: 1,
  },

  lokiCaches: {
    local scConfig = self,
    version: '1.6.3-alpine',
    image: 'docker.io/memcached:' + scConfig.version,
    exporterVersion: 'v0.6.0',
    exporterImage: 'prom/memcached-exporter:' + scConfig.exporterVersion,
    replicas: {
      chunk_cache: 1,
      index_query_cache: 1,
      index_write_cache: 1,
      results_cache: 1,
    },
  },

  loki: {
    local lokiConfig = self,
    version: 'master-815c475',
    image: 'docker.io/grafana/loki:' + lokiConfig.version,
    objectStorageConfig: defaultConfig.objectStorageConfig.loki,
    replicas: {
      distributor: 1,
      ingester: 1,
      querier: 1,
      query_frontend: 1,
      table_manager: 1,
    },
  },
}
