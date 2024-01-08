package query

import (
	"fmt"
	"net"

	cmdopt "github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/cmdoption"
	"github.com/observatorium/observatorium/configuration_go/k8sutil"
	"github.com/prometheus/common/model"

	thanoslog "github.com/observatorium/observatorium/configuration_go/schemas/thanos/log"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/reqlogging"
	trclient "github.com/observatorium/observatorium/configuration_go/schemas/thanos/tracing/client"
	monv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	corev1 "k8s.io/api/core/v1"
)

type GrpcCompressionType string

const (
	defaultNamespace      string              = "observatorium"
	defaultHTTPPort       int                 = 10902
	defaultGRPCPort       int                 = 10901
	GrpcCompressionSnappy GrpcCompressionType = "snappy"
	GrpcCompressionNone   GrpcCompressionType = "none"
)

type tracingConfigFile = k8sutil.ConfigFile

// NewTracingConfigFile returns a new tracing config file option.
func NewTracingConfigFile(value *trclient.TracingConfig) *tracingConfigFile {
	ret := k8sutil.NewConfigFile("/etc/thanos/tracing", "config.yaml", "tracing", "observatorium-thanos-query-tracing")
	if value != nil {
		ret.WithValue(value.String())
	}
	return ret
}

type requestLoggingConfigFile = k8sutil.ConfigFile

// NewRequestLoggingConfigFile returns a new request logging config file option.
func NewRequestLoggingConfigFile(value *reqlogging.RequestConfig) *requestLoggingConfigFile {
	ret := k8sutil.NewConfigFile("/etc/thanos/request-logging", "config.yaml", "request-logging", "observatorium-thanos-query-request-logging")
	if value != nil {
		ret.WithValue(value.String())
	}
	return ret
}

type QueryOptions struct {
	AlertQueryURL                                 string                    `opt:"alert.query-url"`
	EnableFeature                                 string                    `opt:"enable-feature"`
	Endpoint                                      []string                  `opt:"endpoint"`
	EndpointGroup                                 []string                  `opt:"endpoint-group"`
	EndpointStrict                                []string                  `opt:"endpoint-strict"`
	EndpointGroupStrict                           []string                  `opt:"endpoint-group-strict"`
	GrpcAddress                                   *net.TCPAddr              `opt:"grpc-address"`
	GrpcClientsServerName                         string                    `opt:"grpc-client-server-name"`
	GrpcClientsTLSCA                              string                    `opt:"grpc-client-tls-ca"`
	GrpcClientsTLSCert                            string                    `opt:"grpc-client-tls-cert"`
	GrpcClientsTLSKey                             string                    `opt:"grpc-client-tls-key"`
	GrpcClientsTLSSecure                          bool                      `opt:"grpc-client-tls-secure,noval"`
	GrpcClientsTLSSkipVerify                      bool                      `opt:"grpc-client-tls-skip-verify,noval"`
	GrpcClientsCompression                        GrpcCompressionType       `opt:"grpc-compression"`
	GrpcGracePeriod                               model.Duration            `opt:"grpc-grace-period"`
	GrpcMMaxConnectionAge                         model.Duration            `opt:"grpc-server-max-connection-age"`
	GrpcServerTLSCert                             string                    `opt:"grpc-server-tls-cert"`
	GrpcServerTLSClientCA                         string                    `opt:"grpc-server-tls-client-ca"`
	GrpcServerTLSKey                              string                    `opt:"grpc-server-tls-key"`
	HttpAddress                                   *net.TCPAddr              `opt:"http-address"`
	HttpGracePeriod                               model.Duration            `opt:"http-grace-period"`
	HttpConfig                                    string                    `opt:"http-config"`
	LogFormat                                     thanoslog.LogFormat       `opt:"log.format"`
	LogLevel                                      thanoslog.LogLevel        `opt:"log.level"`
	QueryActiveQueryPath                          string                    `opt:"query.active-query-path"`
	QueryAutoDownsampling                         bool                      `opt:"query.auto-downsampling,noval"`
	QueryConnMetricLabel                          []string                  `opt:"query.conn-metric.label"`
	QueryDefaultEvaluationInterval                model.Duration            `opt:"query.default-evaluation-interval"`
	QueryDefaultStep                              model.Duration            `opt:"query.default-step"`
	QueryDefaultTenantID                          string                    `opt:"query.default-tenant-id"`
	QueryLookbackDelta                            model.Duration            `opt:"query.lookback-delta"`
	QueryMaxConcurrent                            int                       `opt:"query.max-concurrent"`
	QueryMaxConcurrentSelect                      int                       `opt:"query.max-concurrent-select"`
	QueryMetadataDefaultTimeRange                 model.Duration            `opt:"query.metadata.default-time-range"`
	QueryPartialResponse                          bool                      `opt:"query.partial-response,noval"`
	QueryPromQLEngine                             string                    `opt:"query.promql-engine"`
	QueryReplicaLabel                             []string                  `opt:"query.replica-label"`
	QueryTelemetryRequestDurationSecondsQuantiles []float64                 `opt:"query.telemetry.request-duration-seconds-quantiles"`
	QueryTelemetryRequestSamplesQuantiles         []float64                 `opt:"query.telemetry.request-samples-quantiles"`
	QueryTelemetryRequestSeriesSecondsQuantiles   []float64                 `opt:"query.telemetry.request-series-seconds-quantiles"`
	QueryTenantCertificateField                   string                    `opt:"query.tenant-certificate-field"`
	QueryTenantHeader                             string                    `opt:"query.tenant-header"`
	QueryTimeout                                  model.Duration            `opt:"query.timeout"`
	RequestLoggingConfig                          *reqlogging.RequestConfig `opt:"request.logging-config"`
	RequestLoggingConfigFile                      *requestLoggingConfigFile `opt:"request.logging-config-file"`
	SelectorLabel                                 []string                  `opt:"selector-label"`
	StoreLimitsRequestSamples                     int                       `opt:"store.limits.request-samples"`
	StoreLimitsRequestSeries                      int                       `opt:"store.limits.request-series"`
	StoreResponseTimeout                          model.Duration            `opt:"store.response-timeout"`
	StoreSDDNSInterval                            model.Duration            `opt:"store.sd-dns-interval"`
	StoreSDFiles                                  []string                  `opt:"store.sd-files"`
	StoreSDInterval                               model.Duration            `opt:"store.sd-interval"`
	StoreUnhealthyTimeout                         model.Duration            `opt:"store.unhealthy-timeout"`
	TracingConfig                                 *trclient.TracingConfig   `opt:"tracing.config"`
	TracingConfigFile                             *tracingConfigFile        `opt:"tracing.config-file"`
	WebDisableCORS                                bool                      `opt:"web.disable-cors,noval"`
	WebExternalPrefix                             string                    `opt:"web.external-prefix"`
	WebPrefixHeader                               string                    `opt:"web.prefix-header"`
	WebRoutePrefix                                string                    `opt:"web.route-prefix"`
}

type QueryDeployment struct {
	Options *QueryOptions

	k8sutil.DeploymentGenericConfig
}

func NewQuery() *QueryDeployment {
	opts := &QueryOptions{
		LogLevel:  "warn",
		LogFormat: "logfmt",
	}

	commonLabels := map[string]string{
		k8sutil.NameLabel:      "thanos-query",
		k8sutil.InstanceLabel:  "observatorium",
		k8sutil.PartOfLabel:    "observatorium",
		k8sutil.ComponentLabel: "query-layer",
	}

	labelSelectors := map[string]string{
		k8sutil.NameLabel:     commonLabels[k8sutil.NameLabel],
		k8sutil.InstanceLabel: commonLabels[k8sutil.InstanceLabel],
	}

	return &QueryDeployment{
		Options: opts,
		DeploymentGenericConfig: k8sutil.DeploymentGenericConfig{
			Image:                "quay.io/thanos/thanos",
			ImagePullPolicy:      corev1.PullIfNotPresent,
			Name:                 "observatorium-thanos-query",
			Namespace:            defaultNamespace,
			CommonLabels:         commonLabels,
			Replicas:             1,
			PodResources:         k8sutil.NewResourcesRequirements("500m", "2", "1Gi", "8Gi"),
			Affinity:             k8sutil.NewAntiAffinity(nil, labelSelectors),
			EnableServiceMonitor: true,

			LivenessProbe: k8sutil.NewProbe("/-/healthy", defaultHTTPPort, k8sutil.ProbeConfig{
				FailureThreshold: 8,
				PeriodSeconds:    30,
				TimeoutSeconds:   1,
			}),
			ReadinessProbe: k8sutil.NewProbe("/-/ready", defaultHTTPPort, k8sutil.ProbeConfig{
				FailureThreshold: 20,
				PeriodSeconds:    5,
			}),
			TerminationGracePeriodSeconds: 120,
			Env: []corev1.EnvVar{
				k8sutil.NewEnvFromField("HOST_IP_ADDRESS", "status.hostIP"),
			},
			ConfigMaps: make(map[string]map[string]string),
			Secrets:    make(map[string]map[string][]byte),
		},
	}
}

func (s *QueryDeployment) Manifests() k8sutil.ObjectMap {
	container := s.makeContainer()

	commonObjectMeta := k8sutil.MetaConfig{
		Name:      s.Name,
		Labels:    s.CommonLabels,
		Namespace: s.Namespace,
	}
	commonObjectMeta.Labels[k8sutil.VersionLabel] = container.ImageTag

	pod := &k8sutil.Pod{
		TerminationGracePeriodSeconds: &s.TerminationGracePeriodSeconds,
		Affinity:                      s.Affinity,
		SecurityContext:               s.SecurityContext,
		ServiceAccountName:            commonObjectMeta.Name,
		ContainerProviders:            append([]k8sutil.ContainerProvider{container}, s.Sidecars...),
	}

	statefulset := &k8sutil.Deployment{
		MetaConfig: commonObjectMeta.Clone(),
		Replicas:   s.Replicas,
		Pod:        pod,
	}

	ret := k8sutil.ObjectMap{
		"query-statefulSet": statefulset.MakeManifest(),
	}

	service := &k8sutil.Service{
		MetaConfig:   commonObjectMeta.Clone(),
		ServicePorts: pod,
	}
	ret["query-service"] = service.MakeManifest()

	if s.EnableServiceMonitor {
		serviceMonitor := &k8sutil.ServiceMonitor{
			MetaConfig:              commonObjectMeta.Clone(),
			ServiceMonitorEndpoints: pod,
		}
		ret["query-serviceMonitor"] = serviceMonitor.MakeManifest()
	}

	serviceAccount := &k8sutil.ServiceAccount{
		MetaConfig: commonObjectMeta.Clone(),
		Name:       pod.ServiceAccountName,
	}
	ret["query-serviceAccount"] = serviceAccount.MakeManifest()

	// Create configMaps required by the containers
	for name, config := range pod.GetConfigMaps() {
		configMap := &k8sutil.ConfigMap{
			MetaConfig: commonObjectMeta.Clone(),
			Data:       config,
		}
		configMap.MetaConfig.Name = name
		ret["query-configMap-"+name] = configMap.MakeManifest()
	}

	// Create secrets required by the containers
	for name, secret := range pod.GetSecrets() {
		secret := &k8sutil.Secret{
			MetaConfig: commonObjectMeta.Clone(),
			Data:       secret,
		}
		secret.MetaConfig.Name = name
		ret["query-secret-"+name] = secret.MakeManifest()
	}

	return ret
}

func (s *QueryDeployment) makeContainer() *k8sutil.Container {
	if s.Options == nil {
		s.Options = &QueryOptions{}
	}

	httpPort := defaultHTTPPort
	if s.Options.HttpAddress != nil && s.Options.HttpAddress.Port != 0 {
		httpPort = s.Options.HttpAddress.Port
	}

	grpcPort := defaultGRPCPort
	if s.Options.GrpcAddress != nil && s.Options.GrpcAddress.Port != 0 {
		grpcPort = s.Options.GrpcAddress.Port
	}

	livenessPort := s.LivenessProbe.ProbeHandler.HTTPGet.Port.IntVal
	if livenessPort != int32(httpPort) {
		panic(fmt.Sprintf(`liveness probe port %d does not match http port %d`, livenessPort, httpPort))
	}

	readinessPort := s.ReadinessProbe.ProbeHandler.HTTPGet.Port.IntVal
	if readinessPort != int32(httpPort) {
		panic(fmt.Sprintf(`readiness probe port %d does not match http port %d`, readinessPort, httpPort))
	}

	ret := s.ToContainer()
	ret.Name = "thanos"
	ret.Args = append([]string{"query"}, cmdopt.GetOpts(s.Options)...)
	ret.Ports = []corev1.ContainerPort{
		{
			Name:          "http",
			ContainerPort: int32(httpPort),
			Protocol:      corev1.ProtocolTCP,
		},
		{
			Name:          "grpc",
			ContainerPort: int32(grpcPort),
			Protocol:      corev1.ProtocolTCP,
		},
	}
	ret.ServicePorts = []corev1.ServicePort{
		k8sutil.NewServicePort("http", httpPort, httpPort),
		k8sutil.NewServicePort("grpc", grpcPort, grpcPort),
	}
	ret.MonitorPorts = []monv1.Endpoint{
		{
			Port:           "http",
			RelabelConfigs: k8sutil.GetDefaultServiceMonitorRelabelConfig(),
		},
	}

	if s.Options.RequestLoggingConfig != nil {
		s.Options.RequestLoggingConfigFile.AddToContainer(ret)
	}

	if s.Options.TracingConfig != nil {
		s.Options.TracingConfigFile.AddToContainer(ret)
	}

	return ret
}
