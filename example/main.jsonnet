local dex = (import '../components/dex.libsonnet') + {
  config+:: {
    local cfg = self,
    name: 'dex',
    namespace: 'dex',
    config+: {
      oauth2: {
        passwordConnector: 'local',
      },
      staticClients: [
        {
          id: 'test',
          name: 'test',
          secret: 'ZXhhbXBsZS1hcHAtc2VjcmV0',
        },
      ],
      enablePasswordDB: true,
      staticPasswords: [
        {
          email: 'admin@example.com',
          // bcrypt hash of the string "password"
          hash: '$2a$10$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W',
          username: 'admin',
          userID: '08a8684b-db88-4b73-90a9-3cd1661f5466',
        },
      ],
    },
    version: 'v2.24.0',
    image: 'quay.io/dexidp/dex:v2.24.0',
    commonLabels+:: {
      'app.kubernetes.io/instance': 'e2e-test',
    },
  },
};

local obs = (import '../environments/base/observatorium.jsonnet');

{
  local cr = self,
  crNoTlsSName:: 'observatorium-cr',
  crWithTlsSName:: 'observatorium-cr-tls',
  crWithMtlsSName:: 'observatorium-cr-mtls',
  config: {
    apiVersion: 'core.observatorium.io/v1alpha1',
    kind: 'Observatorium',
    spec: {
      objectStorageConfig: obs.config.objectStorageConfig,
      hashrings: obs.config.hashrings,

      queryCache: {
        image: obs.config.queryCache.image,
        replicas: obs.config.queryCache.replicas,
        version: obs.config.queryCache.version,
      },
      store: {
        image: obs.config.thanosImage,
        version: obs.config.thanosVersion,
        volumeClaimTemplate: obs.config.store.volumeClaimTemplate,
        shards: obs.config.store.shards,
        cache: {
          image: obs.config.storeCache.image,
          version: obs.config.storeCache.version,
          exporterImage: obs.config.storeCache.exporterImage,
          exporterVersion: obs.config.storeCache.exporterVersion,
          replicas: obs.config.storeCache.replicas,
          memoryLimitMb: obs.config.storeCache.memoryLimitMb,
        },
      },
      compact: {
        image: obs.config.thanosImage,
        version: obs.config.thanosVersion,
        volumeClaimTemplate: obs.config.compact.volumeClaimTemplate,
        retentionResolutionRaw: obs.config.compact.retentionResolutionRaw,
        retentionResolution5m: obs.config.compact.retentionResolution5m,
        retentionResolution1h: obs.config.compact.retentionResolution1h,
      },
      rule: {
        image: obs.config.thanosImage,
        version: obs.config.thanosVersion,
        volumeClaimTemplate: obs.config.rule.volumeClaimTemplate,
      },
      receivers: {
        image: obs.config.thanosImage,
        version: obs.config.thanosVersion,
        volumeClaimTemplate: obs.config.receivers.volumeClaimTemplate,
      },
      thanosReceiveController: {
        image: obs.config.thanosReceiveController.image,
        version: obs.config.thanosReceiveController.version,
      },
      api: {
        image: obs.config.api.image,
        version: obs.config.api.version,
        rbac: {
          roles: [
            {
              name: 'read-write',
              resources: [
                'logs',
                'metrics',
              ],
              tenants: [
                'test',
              ],
              permissions: [
                'read',
                'write',
              ],
            },
          ],
          roleBindings: [
            {
              name: 'test',
              roles: [
                'read-write',
              ],
              subjects: [
                {
                  name: dex.config.config.staticPasswords[0].email,
                  kind: 'user',
                },
              ],
            },
          ],
        },
        tenants: [
          {
            name: dex.config.config.staticClients[0].name,
            id: '1610b0c3-c509-4592-a256-a1871353dbfa',
            oidc: {
              clientID: dex.config.config.staticClients[0].id,
              clientSecret: dex.config.config.staticClients[0].secret,
              issuerURL: 'http://%s.%s.svc.cluster.local:%d/dex' % [
                dex.service.metadata.name,
                dex.service.metadata.namespace,
                dex.service.spec.ports[0].port,
              ],
              usernameClaim: 'email',
            },
          },
        ],
      },
      apiQuery: {
        image: obs.config.thanosImage,
        version: obs.config.thanosVersion,
      },
      query: {
        image: obs.config.thanosImage,
        version: obs.config.thanosVersion,
      },
      loki: {
        image: obs.config.loki.image,
        replicas: obs.config.loki.replicas,
        version: obs.config.loki.version,
      },
    },
  },
  observatorium: cr.config {
    metadata: {
      name: obs.config.name,
      labels: obs.config.commonLabels {
        'app.kubernetes.io/name': cr.crNoTlsSName,
        'app.kubernetes.io/component': cr.crNoTlsSName,
      },
    },
  },
  observatorium_tls: cr.config {
    metadata: {
      name: obs.config.name,
      labels: obs.config.commonLabels {
        'app.kubernetes.io/name': cr.crWithTlsSName,
        'app.kubernetes.io/component': cr.crWithTlsSName,
      },
    },
    spec+: {
      api+: {
        tls: {
          secret: {
            name: obs.config.withTLS.volumeMounts.name,
            privateKeyFile: obs.config.withTLS.serverKey,
            certFile: obs.config.withTLS.serverPem,
            reloadInterval: obs.config.withTLS.reloadInterval,
          },
        },
        mtls: {
          configMap: {
            name: obs.config.withMTLS.volumeMounts.name,
            clientCAFile: obs.config.withMTLS.caPem,
          },
        },
      },
    },
  },
  observatorium_mtls: cr.config {
    metadata: {
      name: obs.config.name,
      labels: obs.config.commonLabels {
        'app.kubernetes.io/name': cr.crWithMtlsSName,
        'app.kubernetes.io/component': cr.crWithMtlsSName,
      },
    },
    spec+: {
      api+: {
        tls: {
          secret: {
            name: obs.config.withTLS.volumeMounts.name,
            privateKeyFile: obs.config.withTLS.serverKey,
            certFile: obs.config.withTLS.serverPem,
            reloadInterval: obs.config.withTLS.reloadInterval,
          },
        },
        mtls: {
          configMap: {
            name: obs.config.withMTLS.volumeMounts.name,
            clientCAFile: obs.config.withMTLS.caPem,
          },
        },
      },
    },
  },
}
