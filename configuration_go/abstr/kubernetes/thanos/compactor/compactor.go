package compactor

import (
	"log"
	"net"
	"time"

	cmdopt "github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/cmdoption"
	"github.com/observatorium/observatorium/configuration_go/k8sutil"
	monv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	corev1 "k8s.io/api/core/v1"
)

const (
	dataVolumeName   string = "data"
	defaultHTTPPort  int    = 10902
	defaultNamespace string = "observatorium"
	servicePortName  string = "http"
	defaultImage     string = "quay.io/thanos/thanos"
	defaultImageTag  string = "v0.31.0"
)

// CompactorOptions represents the options/flags for the compactor.
// See https://thanos.io/tip/components/compact.md/#flags for details.
type CompactorOptions struct {
	BlockFilesConcurrency              int           `opt:"block-files-concurrency"`
	BlockMetaFetchConcurrency          int           `opt:"block-meta-fetch-concurrency"`
	BlockViewerGlobalSyncBlockInterval time.Duration `opt:"block-viewer.global.sync-block-interval"`
	BlockViewerGlobalSyncBlockTimeout  time.Duration `opt:"block-viewer.global.sync-block-timeout"`
	BucketWebLabel                     string        `opt:"bucket-web-label"`
	CompactBlocksFetchConcurrency      int           `opt:"compact.blocks-fetch-concurrency"`
	CompactCleanupInterval             time.Duration `opt:"compact.cleanup-interval"`
	CompactConcurrency                 int           `opt:"compact.concurrency"`
	CompactProgressInterval            time.Duration `opt:"compact.progress-interval"`
	ConsistencyDelay                   time.Duration `opt:"consistency-delay"`
	DataDir                            string        `opt:"data-dir"`
	DeduplicationFunc                  string        `opt:"deduplication.func"`
	DeduplicationReplicaLabel          string        `opt:"deduplication.replica-label"`
	DeleteDelay                        time.Duration `opt:"delete-delay"`
	DownsampleConcurrency              int           `opt:"downsample.concurrency"`
	DownsamplingDisable                bool          `opt:"downsampling.disable"`
	HashFunc                           string        `opt:"hash-func"`
	HttpAddress                        net.TCPAddr   `opt:"http-address"`
	HttpGracePeriod                    time.Duration `opt:"http-grace-period"`
	HttpConfig                         string        `opt:"http.config"`
	LogFormat                          string        `opt:"log.format"`
	LogLevel                           string        `opt:"log.level"`
	MaxTime                            string        `opt:"max-time"`
	MinTime                            string        `opt:"min-time"`
	ObjstoreConfig                     string        `opt:"objstore.config"`
	ObjstoreConfigFile                 string        `opt:"objstore.config-file"`
	RetentionResolution1h              time.Duration `opt:"retention.resolution-1h"`
	RetentionResolution5m              time.Duration `opt:"retention.resolution-5m"`
	RetentionResolutionRaw             time.Duration `opt:"retention.resolution-raw"`
	SelectorRelabelConfig              string        `opt:"selector.relabel-config"`
	SelectorRelabelConfigFile          string        `opt:"selector.relabel-config-file"`
	TracingConfig                      string        `opt:"tracing.config"`
	TracingConfigFile                  string        `opt:"tracing.config-file"`
	Version                            bool          `opt:"version,noval"`
	Wait                               bool          `opt:"wait,noval"`
	WaitInterval                       time.Duration `opt:"wait-interval"`
	WebDisable                         bool          `opt:"web.disable"`
	WebDisableCors                     bool          `opt:"web.disable-cors"`
	WebExternalPrefix                  string        `opt:"web.external-prefix"`
	WebPrefixHeader                    string        `opt:"web.prefix-header"`
	WebRoutePrefix                     string        `opt:"web.route-prefix"`

	// Extra options not officially supported by the compactor.
	cmdopt.ExtraOpts
}

type CompactorStatefulSet struct {
	Options    *CompactorOptions
	VolumeType string
	VolumeSize string

	k8sutil.DeploymentGenericConfig
}

func (c *CompactorStatefulSet) WithLogLevel(level string) *CompactorStatefulSet {
	c.Options.LogLevel = level
	return c
}

// NewCompactor returns a new compactor statefulset with default values.
// It allows generating the all the manifests for the compactor.
func NewCompactor() *CompactorStatefulSet {
	c := &CompactorOptions{
		ObjstoreConfig:            "$(OBJSTORE_CONFIG)",
		Wait:                      true,
		LogLevel:                  "warn",
		LogFormat:                 "logfmt",
		DataDir:                   "/var/thanos/compactor",
		RetentionResolutionRaw:    time.Hour * 24 * 365,
		DeleteDelay:               time.Hour * 24 * 2,
		CompactConcurrency:        1,
		DownsampleConcurrency:     1,
		DeduplicationReplicaLabel: "replica",
	}

	commonLabels := map[string]string{
		k8sutil.NameLabel:      "thanos-compact",
		k8sutil.InstanceLabel:  "observatorium",
		k8sutil.PartOfLabel:    "observatorium",
		k8sutil.ComponentLabel: "database-compactor",
	}

	labelSelectors := map[string]string{
		k8sutil.NameLabel:     commonLabels[k8sutil.NameLabel],
		k8sutil.InstanceLabel: commonLabels[k8sutil.InstanceLabel],
	}

	namespaces := []string{defaultNamespace}

	return &CompactorStatefulSet{
		Options: c,
		DeploymentGenericConfig: k8sutil.DeploymentGenericConfig{
			Image:                defaultImage,
			ImageTag:             defaultImageTag,
			ImagePullPolicy:      corev1.PullIfNotPresent,
			Name:                 "observatorium-thanos-compact",
			Namespace:            defaultNamespace,
			CommonLabels:         commonLabels,
			Replicas:             1,
			PodResources:         k8sutil.NewResourcesRequirements("2", "3", "2000Mi", "3000Mi"),
			Affinity:             *k8sutil.NewAntiAffinity(namespaces, labelSelectors),
			SecurityContext:      k8sutil.GetDefaultSecurityContext(),
			EnableServiceMonitor: true,
			LivenessProbe: k8sutil.NewProbe("/-/healthy", defaultHTTPPort, k8sutil.ProbeConfig{
				FailureThreshold: 4,
				PeriodSeconds:    30,
			}),
			ReadinessProbe: k8sutil.NewProbe("/-/ready", defaultHTTPPort, k8sutil.ProbeConfig{
				FailureThreshold: 20,
				PeriodSeconds:    5,
			}),
			TerminationGracePeriodSeconds: 120,
			ConfigMaps:                    make(map[string]map[string]string),
			Env: []corev1.EnvVar{
				k8sutil.NewEnvFromSecret("OBJSTORE_CONFIG", "objectStore-secret", "thanos.yaml"),
				k8sutil.NewEnvFromField("HOST_IP_ADDRESS", "status.hostIP"),
			},
		},
		VolumeType: "gp2-csi",
		VolumeSize: "50Gi",
	}
}

// Manifests returns the manifests for the compactor.
// It includes the statefulset, the service, the service monitor, the service account and the config maps required by the containers.
func (c *CompactorStatefulSet) Manifests() k8sutil.ObjectMap {
	container := c.makeContainer()

	commonObjectMeta := k8sutil.MetaConfig{
		Name:      c.Name,
		Labels:    c.CommonLabels,
		Namespace: c.Namespace,
	}
	commonObjectMeta.Labels[k8sutil.VersionLabel] = container.ImageTag

	pod := &k8sutil.Pod{
		TerminationGracePeriodSeconds: &c.TerminationGracePeriodSeconds,
		Affinity:                      &c.Affinity,
		SecurityContext:               c.SecurityContext,
		ServiceAccountName:            commonObjectMeta.Name,
		ContainerProviders:            append([]k8sutil.ContainerProvider{container}, c.Sidecars...),
	}

	statefulset := &k8sutil.StatefulSet{
		MetaConfig: commonObjectMeta,
		Replicas:   c.Replicas,
		Pod:        pod,
	}

	ret := k8sutil.ObjectMap{
		"compactor-statefulSet": statefulset.MakeManifest(),
	}

	service := &k8sutil.Service{
		MetaConfig:   commonObjectMeta,
		ServicePorts: pod,
	}
	ret["compactor-service"] = service.MakeManifest()

	if c.EnableServiceMonitor {
		serviceMonitor := &k8sutil.ServiceMonitor{
			MetaConfig:              commonObjectMeta,
			ServiceMonitorEndpoints: pod,
		}
		ret["compactor-serviceMonitor"] = serviceMonitor.MakeManifest()
	}

	serviceAccount := &k8sutil.ServiceAccount{
		MetaConfig: commonObjectMeta,
		Name:       pod.ServiceAccountName,
	}
	ret["compactor-serviceAccount"] = serviceAccount.MakeManifest()

	// Add needed configMaps
	for k, v := range c.ConfigMaps {
		configMap := &k8sutil.ConfigMap{
			MetaConfig: commonObjectMeta,
			Data:       v,
		}
		configMap.MetaConfig.Name = k
		ret["compactor-configMap-"+k] = configMap.MakeManifest()
	}

	// Create confiMaps required by the containers
	for name, config := range pod.GetConfigMaps() {
		configMap := &k8sutil.ConfigMap{
			MetaConfig: commonObjectMeta,
			Data:       config,
		}
		configMap.MetaConfig.Name = name
		ret["compactor-configMap-"+name] = configMap.MakeManifest()
	}

	return ret
}

func (c *CompactorStatefulSet) makeContainer() *k8sutil.Container {
	if c.Options == nil {
		c.Options = &CompactorOptions{}
	}

	httpPort := defaultHTTPPort
	if c.Options.HttpAddress.Port != 0 {
		httpPort = c.Options.HttpAddress.Port
	}

	if c.LivenessProbe.ProbeHandler.HTTPGet.Port.IntVal != int32(httpPort) {
		log.Printf("Warning: liveness probe port %d does not match http port %d", c.LivenessProbe.ProbeHandler.HTTPGet.Port.IntVal, httpPort)
	}

	if c.ReadinessProbe.ProbeHandler.HTTPGet.Port.IntVal != int32(httpPort) {
		log.Printf("Warning: readiness probe port %d does not match http port %d", c.ReadinessProbe.ProbeHandler.HTTPGet.Port.IntVal, httpPort)
	}

	// Print warning if data directory is not specified.
	if c.Options.DataDir == "" {
		log.Println("Warning: data directory is not specified for the statefulset.")
	}

	ret := c.ToContainer()
	ret.Name = "thanos"
	ret.Args = append([]string{"compact"}, cmdopt.GetOpts(c.Options)...)
	ret.Ports = []corev1.ContainerPort{
		{
			Name:          "http",
			ContainerPort: int32(httpPort),
			Protocol:      corev1.ProtocolTCP,
		},
	}
	ret.ServicePorts = []corev1.ServicePort{
		k8sutil.NewServicePort("http", httpPort, httpPort),
	}
	ret.MonitorPorts = []monv1.Endpoint{
		{
			Port:           "http",
			RelabelConfigs: k8sutil.GetDefaultServiceMonitorRelabelConfig(),
		},
	}
	ret.VolumeClaims = []k8sutil.VolumeClaim{
		k8sutil.NewVolumeClaimProvider(dataVolumeName, c.VolumeType, c.VolumeSize),
	}

	return ret
}
