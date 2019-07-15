local sm =
  (import 'kube-thanos/kube-thanos-servicemonitors.libsonnet') +
  {
    thanos+:: {
      querier+: {
        serviceMonitor+: {
          metadata: {
            name: 'thanos-querier',
            labels: { prometheus: 'app-sre' },
          },
          spec+: {
            selector+: {
              matchLabels: { app: 'thanos-querier' },
            },
            namespaceSelector: {
              matchLabels: ['telemeter-stage'],
            },
          },
        },
      },
      store+: {
        serviceMonitor+: {
          metadata: {
            name: 'thanos-store',
            labels: { prometheus: 'app-sre' },
          },
          spec+: {
            selector+: {
              matchLabels: { app: 'thanos-store' },
            },
            namespaceSelector: {
              matchLabels: ['telemeter-stage'],
            },
          },
        },
      },
      receive+: {
        serviceMonitor+: {
          metadata: {
            name: 'thanos-receive',
            labels: { prometheus: 'app-sre' },
          },
          spec+: {
            selector+: {
              matchLabels: { app: 'thanos-receive' },
            },
            namespaceSelector: {
              matchLabels: ['telemeter-stage'],
            },
          },
        },
      },
    },
  };

{
  'observatorium-thanos-querier-serviceMonitor': sm.thanos.querier.serviceMonitor,
  'observatorium-thanos-store-serviceMonitor': sm.thanos.store.serviceMonitor,
  'observatorium-thanos-receive-serviceMonitor': sm.thanos.receive.serviceMonitor,
}
