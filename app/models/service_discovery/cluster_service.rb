# frozen_string_literal: true

module ServiceDiscovery
  class ClusterService < NamespacedClusterResource
    # See https://github.com/kubernetes/kubernetes/blob/release-1.4/docs/proposals/service-discovery.md

    KUBERNETES_NAMESPACE = 'api.service.kubernetes.io'
    KUBERNETES_SERVICE_DISCOVERY_FIELDS = %w[scheme path protocol description-path description-language].freeze

    KUBERNETES_SERVICE_DISCOVERY_FIELDS.each do |field_name|
      define_method(field_name.tr('-', '_').to_sym) do
        discovery_annotation(field_name)
      end
    end

    def discoverable?
      scheme.present?
    end

    def endpoint
      "#{scheme}://#{name}.#{namespace}.svc.cluster.local:#{port}/#{path}"
    end

    def ports
      (spec[:ports] || []).map(&:to_h)
    end

    def port
      # https://docs.google.com/a/redhat.com/document/d/1QsunYWA9jy1VRjkIeWFUwEScSXsmaAYmuwEF1Zs5SoU/edit?disco=uiAAAACISXQJA
      http_port = ports.find { |port| port[:name] == scheme } || ports.find { |port| port[:protocol] == 'TCP' } || {}
      http_port[:targetPort]
    end

    def description
      resource.to_h.to_yaml
    end

    protected

    def discovery_annotation_key(field_name)
      "#{KUBERNETES_NAMESPACE}/#{field_name}".to_sym
    end

    def discovery_annotation(field_name)
      annotations[discovery_annotation_key(field_name)]
    end
  end
end
