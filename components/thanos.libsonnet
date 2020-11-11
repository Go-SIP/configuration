local t = (import 'kube-thanos/thanos.libsonnet');
local rc = (import 'thanos-receive-controller/thanos-receive-controller.libsonnet');
local memcached = (import 'memcached.libsonnet');

local storeShards(shards, cfg) = {
  ['shard' + i]: t.store(cfg {
    name+: '-%d' % i,
    commonLabels+:: { 'store.observatorium.io/shard': 'shard-' + i },
  }) {
    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-store' then c {
                args+: [
                  |||
                    --selector.relabel-config=
                      - action: hashmod
                        source_labels: ["__block_id"]
                        target_label: shard
                        modulus: %d
                      - action: keep
                        source_labels: ["shard"]
                        regex: %d
                  ||| % [shards, i],
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  }
  for i in std.range(0, shards - 1)
};

local receiveRings(hashrings, cfg) = {
  [hashring.hashring]: t.receive(cfg {
    name+: '-' + hashring.hashring,
    commonLabels+:: {
      'controller.receive.thanos.io/hashring': hashring.hashring,
    },
    replicas: 1,
  }) {
    local receiver = self,
    podDisruptionBudget:: {},  // hide this object, we don't want it
    statefulSet+: {
      metadata+: {
        labels+: {
          'controller.receive.thanos.io': 'thanos-receive-controller',
        },
      },
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-receive' then c {
                env+: [
                  {
                    name: 'DEBUG',
                    value: receiver.config.debug,
                  },
                ],
              }
              else c
              for c in super.containers
            ],
          },
        },
      },
    },
  }
  for hashring in hashrings
};

// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,
  name: 'observatorum-xyz',
  namespace: 'observatorium',
  version: 'master-2020-11-04-a4576d85',
  image: 'quay.io/thanos/thanos:' + defaults.version,
  objectStorageConfig: {
    name: 'thanos-objectstorage',
    key: 'thanos.yaml',
  },
  hashrings: [{
    hashring: 'default',
    tenants: [],
  }],
  stores: { shards: 1 },
  replicaLabels: ['prometheus_replica', 'rule_replica', 'replica'],
  deduplicationReplicaLabels: ['replica'],

  commonLabels: {
    'app.kubernetes.io/part-of': 'observatorium',
    'app.kubernetes.io/instance': defaults.name,
  },

  podLabelSelector:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
};

function(params) {
  local thanos = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,

  // Safety checks for combined config of defaults and params.
  assert std.isObject(thanos.config.objectStorageConfig),
  assert std.isArray(thanos.config.hashrings),
  assert std.isObject(thanos.config.stores),

  compact:: t.compact({
    name: '%s-thanos-compact' % thanos.config.name,
    namespace: thanos.config.namespace,
    commonLabels+:: thanos.config.commonLabels,
    image: thanos.config.image,
    version: thanos.config.version,
    replicas: 1,
    deduplicationReplicaLabels: thanos.config.deduplicationReplicaLabels,
    deleteDelay: '48h',
    disableDownsampling: true,
    retentionResolutionRaw: '14d',
    retentionResolution5m: '1s',
    retentionResolution1h: '1s',
    objectStorageConfig: thanos.config.objectStorageConfig,
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
  }),

  receiveController:: rc({
    local cfg = self,
    commonLabels+:: thanos.config.commonLabels,
    name: thanos.config.name + '-' + cfg.commonLabels['app.kubernetes.io/name'],
    namespace: thanos.config.namespace,
    replicas: 1,
    version: 'master-2020-02-06-b66e0c8',
    image: 'quay.io/observatorium/thanos-receive-controller:' + cfg.version,
    hashrings: thanos.config.hashrings,
    serviceMonitor: false,
  }),

  receiversService:: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: '%s-thanos-receive' % thanos.config.name,
      namespace: thanos.config.namespace,
      labels: thanos.config.commonLabels { 'app.kubernetes.io/name': 'thanos-receive' },
    },
    spec: {
      selector: { 'app.kubernetes.io/name': 'thanos-receive' },
      ports: [
        { name: 'grpc', port: 10901, targetPort: 10901 },
        { name: 'http', port: 10902, targetPort: 10902 },
        { name: 'remote-write', port: 19291, targetPort: 19291 },
      ],
    },
  },

  receivers:: receiveRings(thanos.config.hashrings, {
    name: thanos.config.name + '-thanos-receive',
    namespace: thanos.config.namespace,
    commonLabels+:: thanos.config.commonLabels,
    image: thanos.config.image,
    version: thanos.config.version,
    hashrings: thanos.config.hashrings,
    replicaLabels: thanos.config.replicaLabels,
    replicationFactor: 1,
    retention: '4d',
    objectStorageConfig: thanos.config.objectStorageConfig,
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
    hashringConfigMapName: '%s-generated' % thanos.receiveController.configmap.metadata.name,
    logLevel: 'info',
    debug: '',
  }),

  rule:: t.rule({
    name: thanos.config.name + '-' + 'thanos-rule',
    namespace: thanos.config.namespace,
    commonLabels+:: thanos.config.commonLabels,
    replicas: 1,
    image: thanos.config.image,
    version: thanos.config.version,
    objectStorageConfig: thanos.config.objectStorageConfig,
    queriers: ['dnssrv+_http._tcp.%s.%s.svc.cluster.local' % [thanos.query.service.metadata.name, thanos.query.service.metadata.namespace]],
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
  }),

  stores:: storeShards(thanos.config.stores.shards, {
    name: thanos.config.name + '-thanos-store-shard',
    namespace: thanos.config.namespace,
    commonLabels+:: thanos.config.commonLabels,
    image: thanos.config.image,
    version: thanos.config.version,
    objectStorageConfig: thanos.config.objectStorageConfig,
    replicas: 1,
    ignoreDeletionMarksDelay: '24h',
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
    local memcachedDefaults = {
      timeout: '2s',
      max_idle_connections: 1000,
      max_async_concurrency: 100,
      max_async_buffer_size: 100000,
      max_get_multi_concurrency: 900,
      max_get_multi_batch_size: 1000,
    },
    indexCache: {
      type: 'memcached',
      config+: memcachedDefaults {
        addresses: ['dnssrv+_client._tcp.%s.%s.svc' % [thanos.storeCache.service.metadata.name, thanos.storeCache.service.metadata.namespace]],
      },
    },
    bucketCache: {
      type: 'memcached',
      config+: memcachedDefaults {
        addresses: ['dnssrv+_client._tcp.%s.%s.svc' % [thanos.storeCache.service.metadata.name, thanos.storeCache.service.metadata.namespace]],
      },
    },
  }),

  storeCache:: memcached({
    local cfg = self,
    name: thanos.config.name + '-thanos-store-' + cfg.commonLabels['app.kubernetes.io/name'],
    namespace: thanos.config.namespace,
    commonLabels+:: thanos.config.commonLabels,
    version: '1.6.3-alpine',
    image: 'docker.io/memcached:' + cfg.version,
    exporterVersion: 'v0.6.0',
    exporterImage: 'prom/memcached-exporter:' + cfg.exporterVersion,
    replicas: 1,
    cpuRequest:: '50m',
    cpuLimit:: '50m',
    memoryLimitMb: 1024,
    memoryRequestBytes: 128 * 1024 * 1024,
    memoryLimitBytes: 256 * 1024 * 1024,
  }),

  query:: t.query({
    name: '%s-thanos-query' % thanos.config.name,
    namespace: thanos.config.namespace,
    commonLabels+:: thanos.config.commonLabels,
    image: thanos.config.image,
    version: thanos.config.version,
    replicas: 1,
    queryTimeout: '15m',
    stores: [
      'dnssrv+_grpc._tcp.%s.%s.svc.cluster.local' % [service.metadata.name, service.metadata.namespace]
      for service in
        [thanos.rule.service] +
        [thanos.stores[shard].service for shard in std.objectFields(thanos.stores)] +
        [thanos.receivers[hashring].service for hashring in std.objectFields(thanos.receivers)]
    ],
    replicaLabels: thanos.config.replicaLabels,
  }),

  queryFrontend:: t.queryFrontend({
    name: '%s-thanos-query-frontend' % thanos.config.name,
    namespace: thanos.config.namespace,
    commonLabels+:: thanos.config.commonLabels,
    image: thanos.config.image,
    version: thanos.config.version,
    replicas: 1,
    downstreamURL: 'http://%s.%s.svc.cluster.local.:%d' % [
      thanos.query.service.metadata.name,
      thanos.query.service.metadata.namespace,
      thanos.query.service.spec.ports[1].port,
    ],
    splitInterval: '24h',
    maxRetries: 0,
    logQueriesLongerThan: '5s',
    serviceMonitor: false,
    queryRangeCache: {
      type: 'memcached',
      config+: {
        addresses: ['dnssrv+_client._tcp.%s.%s.svc' % [thanos.queryFrontendCache.service.metadata.name, thanos.queryFrontendCache.service.metadata.namespace]],
      },
    },
    labelsCache: {
      type: 'memcached',
      config+: {
        addresses: ['dnssrv+_client._tcp.%s.%s.svc' % [thanos.queryFrontendCache.service.metadata.name, thanos.queryFrontendCache.service.metadata.namespace]],
      },
    },
  }),

  queryFrontendCache:: memcached({
    local cfg = self,
    name: thanos.config.name + '-thanos-query-frontend-' + cfg.commonLabels['app.kubernetes.io/name'],
    namespace: thanos.config.namespace,
    commonLabels+:: thanos.config.commonLabels,
    component: 'query-frontend-cache',
    version: '1.6.3-alpine',
    image: 'docker.io/memcached:' + cfg.version,
    exporterVersion: 'v0.6.0',
    exporterImage: 'prom/memcached-exporter:' + cfg.exporterVersion,
    replicas: 1,
    cpuRequest:: '50m',
    cpuLimit:: '50m',
    memoryLimitMb: 1024,
    memoryRequestBytes: 128 * 1024 * 1024,
    memoryLimitBytes: 256 * 1024 * 1024,
  }),

  manifests:: {
    ['query-' + name]: thanos.query[name]
    for name in std.objectFields(thanos.query)
    if thanos.query[name] != null
  } + {
    ['query-frontend-' + name]: thanos.queryFrontend[name]
    for name in std.objectFields(thanos.queryFrontend)
    if thanos.queryFrontend[name] != null
  } + {
    ['query-frontend-cache-' + name]: thanos.queryFrontendCache[name]
    for name in std.objectFields(thanos.queryFrontendCache)
    if thanos.queryFrontendCache[name] != null
  } + {
    ['receive-' + hashring + '-' + name]: thanos.receivers[hashring][name]
    for hashring in std.objectFields(thanos.receivers)
    for name in std.objectFields(thanos.receivers[hashring])
    if thanos.receivers[hashring][name] != null
  } + {
    'receive-service': thanos.receiversService,
  } + {
    ['compact-' + name]: thanos.compact[name]
    for name in std.objectFields(thanos.compact)
    if thanos.compact[name] != null
  } + {
    ['store-' + shard + '-' + name]: thanos.stores[shard][name]
    for shard in std.objectFields(thanos.stores)
    for name in std.objectFields(thanos.stores[shard])
    if thanos.stores[shard][name] != null
  } + {
    ['store-cache-' + name]: thanos.storeCache[name]
    for name in std.objectFields(thanos.storeCache)
    if thanos.storeCache[name] != null
  } + {
    ['rule-' + name]: thanos.rule[name]
    for name in std.objectFields(thanos.rule)
    if thanos.rule[name] != null
  } + {
    ['receive-controller-' + name]: thanos.receiveController[name]
    for name in std.objectFields(thanos.receiveController)
    if thanos.receiveController[name] != null
  },
}
