local tenants = import '../../tenants.libsonnet';
local prom = import '../openshift/prometheus.libsonnet';
local sm =
  (import 'kube-thanos/kube-thanos-servicemonitors.libsonnet') +
  {
    thanos+:: {
      querier+: {
        serviceMonitor+: {
          metadata: {
            name: 'observatorium-thanos-querier',
            labels: { prometheus: 'app-sre' },
          },
          spec+: {
            selector+: {
              matchLabels: { 'app.kubernetes.io/name': 'thanos-querier' },
            },
          },
        },
      },
      store+: {
        serviceMonitor+: {
          metadata: {
            name: 'observatorium-thanos-store',
            labels: { prometheus: 'app-sre' },
          },
          spec+: {
            selector+: {
              matchLabels: { 'app.kubernetes.io/name': 'thanos-store' },
            },
          },
        },
      },
      compactor+: {
        serviceMonitor+: {
          metadata: {
            name: 'observatorium-thanos-compactor',
            labels: { prometheus: 'app-sre' },
          },
          spec+: {
            selector+: {
              matchLabels: { 'app.kubernetes.io/name': 'thanos-compactor' },
            },
          },
        },
      },
      thanosReceiveController+: {
        serviceMonitor+: {
          apiVersion: 'monitoring.coreos.com/v1',
          kind: 'ServiceMonitor',
          metadata: {
            name: 'observatorium-thanos-receive-controller',
            labels: { prometheus: 'app-sre' },
          },
          spec+: {
            selector+: {
              matchLabels: { 'app.kubernetes.io/name': 'thanos-receive-controller' },
            },
          },
          endpoints: [
            { port: 'http' },
          ],
        },
      },
      receive+: {
        ['serviceMonitor' + tenant.hashring]:
          super.serviceMonitor +
          {
            metadata: {
              name: 'observatorium-thanos-receive-' + tenant.hashring,
              labels: { prometheus: 'app-sre' },
            },
            spec+: {
              selector+: {
                matchLabels: {
                  'app.kubernetes.io/name': 'thanos-receive',
                  'app.kubernetes.io/instance': tenant.hashring,
                },
              },
            },
          }
        for tenant in tenants
      },
    },
  };

{
  'observatorium-thanos-querier-stage.servicemonitor': sm.thanos.querier.serviceMonitor {
    metadata+: { name+: '-stage' },
    spec+: { namespaceSelector+: { matchNames: ['telemeter-stage'] } },
  },
  'observatorium-thanos-store-stage.servicemonitor': sm.thanos.store.serviceMonitor {
    metadata+: { name+: '-stage' },
    spec+: { namespaceSelector+: { matchNames: ['telemeter-stage'] } },
  },
  'observatorium-thanos-compactor-stage.servicemonitor': sm.thanos.compactor.serviceMonitor {
    metadata+: { name+: '-stage' },
    spec+: { namespaceSelector+: { matchNames: ['telemeter-stage'] } },
  },
  'observatorium-thanos-receive-controller-stage.servicemonitor': sm.thanos.thanosReceiveController.serviceMonitor {
    metadata+: { name+: '-stage' },
    spec+: { namespaceSelector+: { matchNames: ['telemeter-stage'] } },
  },
  'observatorium-prometheus-ams-stage.servicemonitor': prom.prometheusAms.serviceMonitor {
    metadata: { name: prom.prometheusAms.serviceMonitor.metadata.name + '-stage', labels: { prometheus: 'app-sre' } },
    spec+: { namespaceSelector+: { matchNames: ['telemeter-stage'] } },
  },
  'observatorium-thanos-querier-production.servicemonitor': sm.thanos.querier.serviceMonitor {
    metadata+: { name+: '-production' },
    spec+: { namespaceSelector+: { matchNames: ['telemeter-production'] } },
  },
  'observatorium-thanos-store-production.servicemonitor': sm.thanos.store.serviceMonitor {
    metadata+: { name+: '-production' },
    spec+: { namespaceSelector+: { matchNames: ['telemeter-production'] } },
  },
  'observatorium-thanos-compactor-production.servicemonitor': sm.thanos.compactor.serviceMonitor {
    metadata+: { name+: '-production' },
    spec+: { namespaceSelector+: { matchNames: ['telemeter-production'] } },
  },
  'observatorium-thanos-receive-controller-production.servicemonitor': sm.thanos.thanosReceiveController.serviceMonitor {
    metadata+: { name+: '-production' },
    spec+: { namespaceSelector+: { matchNames: ['telemeter-production'] } },
  },
  'observatorium-prometheus-ams-production.servicemonitor': prom.prometheusAms.serviceMonitor {
    metadata: { name: prom.prometheusAms.serviceMonitor.metadata.name + '-production', labels: { prometheus: 'app-sre' } },
    spec+: { namespaceSelector+: { matchNames: ['telemeter-production'] } },
  },
} {
  ['observatorium-thanos-receive-%s-stage.servicemonitor' % tenant.hashring]: sm.thanos.receive['serviceMonitor' + tenant.hashring] {
    metadata+: { name+: '-stage' },
    spec+: { namespaceSelector+: { matchNames: ['telemeter-stage'] } },
  }
  for tenant in tenants
} {
  ['observatorium-thanos-receive-%s-production.servicemonitor' % tenant.hashring]: sm.thanos.receive['serviceMonitor' + tenant.hashring] {
    metadata+: { name+: '-production' },
    spec+: { namespaceSelector+: { matchNames: ['telemeter-production'] } },
  }
  for tenant in tenants
}
