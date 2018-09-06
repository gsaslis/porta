# frozen_string_literal: true

require 'test_helper'

module ServiceDiscovery
  class ClusterServiceTest < ActiveSupport::TestCase
    include TestHelpers::ServiceDiscovery

    setup do
      @cluster_service_data = {
        metadata: {
          name: 'fake-api',
          namespace: 'fake-project',
          selfLink: '/api/v1/namespaces/fake-project/services/fake-api',
          uid: 'bc6ad9cd-99f2-43a3-91b2-93b7038b0454',
          resourceVersion: '40582387',
          creationTimestamp: '2018-07-17T14:18:55Z',
          labels: { app: 'fake-api', template: 'fake-template' },
          annotations: {
            :'api.service.kubernetes.io/path' => 'api',
            :'api.service.kubernetes.io/protocol' => 'REST',
            :'api.service.kubernetes.io/scheme' => 'http',
            :'api.service.kubernetes.io/description-path' => 'api/doc',
            :'api.service.kubernetes.io/description-language' => 'SwaggerJSON'
          }
        },
        spec: {
          ports: [{ name: 'http', protocol: 'TCP', port: 8080, targetPort: 8081 }],
          selector: { app: 'fake-api' },
          clusterIP: '122.50.171.300',
          type: 'ClusterIP',
          sessionAffinity: 'None'
        },
        status: { loadBalancer: {} }
      }
      @cluster_service = ClusterService.new(cluster_service(@cluster_service_data))
    end

    test 'protocol' do
      assert_equal 'REST', @cluster_service.protocol
    end

    test 'scheme' do
      assert_equal 'http', @cluster_service.scheme
    end

    test 'path' do
      assert_equal 'api', @cluster_service.path
    end

    test 'ports' do
      assert_same_elements [{ name: 'http', protocol: 'TCP', port: 8080, targetPort: 8081 }], @cluster_service.ports
    end

    test 'port' do
      assert_equal 8081, @cluster_service.port

      cluster_service_data = @cluster_service_data.deep_merge(spec: { ports: [{ protocol: 'UDP', port: 1234, targetPort: 4321 }, { protocol: 'TCP', port: 8080, targetPort: 8082 }] })
      assert_equal 8082, ClusterService.new(cluster_service(cluster_service_data)).port
    end

    test 'description path' do
      assert_equal 'api/doc', @cluster_service.description_path
    end

    test 'description language' do
      assert_equal 'SwaggerJSON', @cluster_service.description_language
    end

    test 'endpoint' do
      assert_equal 'http://fake-api.fake-project.svc.cluster.local:8081/api', @cluster_service.endpoint
    end

    test 'discoverable?' do
      assert @cluster_service.discoverable?

      undiscoverable_cluster_service_data = @cluster_service_data.dup
      undiscoverable_cluster_service_data[:metadata][:annotations] = {
        :'api.service.kubernetes.io/path' => 'api',
        :'api.service.kubernetes.io/protocol' => 'REST',
        :'api.service.kubernetes.io/description-path' => 'api/doc',
        :'api.service.kubernetes.io/description-language' => 'SwaggerJSON'
      }
      undiscoverable_cluster_service = ClusterService.new(cluster_service(undiscoverable_cluster_service_data))
      refute undiscoverable_cluster_service.discoverable?
    end
  end
end
