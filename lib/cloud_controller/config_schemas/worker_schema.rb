require 'vcap/config'

module VCAP::CloudController
  module ConfigSchemas
    class WorkerSchema < VCAP::Config
      # rubocop:disable Metrics/BlockLength
      define_schema do
        {
          external_port: Integer,
          external_domain: String,
          tls_port: Integer,
          external_protocol: String,
          internal_service_hostname: String,

          default_health_check_timeout: Integer,

          uaa: {
            internal_url: String,
            ca_file: String,
          },

          logging: {
            :level => String, # debug, info, etc.
            :file => String, # Log file to use
            :syslog => String, # Name to associate with syslog messages (should start with 'vcap.')
          },

          stacks_file: String,
          newrelic_enabled: bool,
          hostname: String,

          :db => {
            :database => String, # db connection string for sequel
            :max_connections => Integer, # max connections in the connection pool
            :pool_timeout => Integer, # timeout before raising an error when connection can't be established to the db
            :log_level => String, # debug, info, etc.
            :ssl_verify_hostname => bool,
            optional(:ca_cert_path) => String,
          },

          internal_api: {
            auth_user: String,
            auth_password: String,
          },

          staging: {
            timeout_in_seconds: Integer,
            auth: {
              user: String,
              password: String,
            }
          },

          default_account_capacity: {
            memory: Integer, #:default => 2048,
            app_uris: Integer, #:default => 4,
            services: Integer, #:default => 16,
            apps: Integer, #:default => 20
          },

          admin_account_capacity: {
            memory: Integer, #:default => 2048,
            app_uris: Integer, #:default => 4,
            services: Integer, #:default => 16,
            apps: Integer, #:default => 20
          },

          index: Integer, # Component index (cc-0, cc-1, etc)
          name: String, # Component name (api_z1, api_z2)
          local_route: String, # If set, use this to determine the IP address that is returned in discovery messages

          nginx: {
            use_nginx: bool,
            instance_socket: String,
          },

          resource_pool: {
            :maximum_size => Integer,
            :minimum_size => Integer,
            :resource_directory_key => String,
            :fog_connection => Hash,
            :fog_aws_storage_options => Hash
          },

          buildpacks: {
            :buildpack_directory_key => String,
            :fog_connection => Hash,
            :fog_aws_storage_options => Hash
          },

          packages: {
            :max_package_size => Integer,
            :max_valid_packages_stored => Integer,
            :app_package_directory_key => String,
            :fog_connection => Hash,
            :fog_aws_storage_options => Hash
          },

          droplets: {
            droplet_directory_key: String,
            :max_staged_droplets_stored => Integer,
            :fog_connection => Hash,
            :fog_aws_storage_options => Hash
          },

          db_encryption_key: String,

          varz_port: Integer,
          varz_user: String,
          varz_password: String,
          broker_client_timeout_seconds: Integer,
          broker_client_default_async_poll_interval_seconds: Integer,
          broker_client_max_async_poll_duration_minutes: Integer,
          uaa_client_name: String,
          uaa_client_secret: String,
          uaa_client_scope: String,

          cloud_controller_username_lookup_client_name: String,
          cloud_controller_username_lookup_client_secret: String,

          loggregator: {
            :router => String,
            :internal_url => String,
          },

          skip_cert_verify: bool,

          install_buildpacks: [
            {
              'name' => String,
              'package' => String,
              'file' => String,
              'enabled' => bool,
              'locked' => bool,
              'position' => Integer,
            }
          ],

          default_locale: String,
          allowed_cors_domains: [String],

          users_can_select_backend: bool,
          optional(:routing_api) => {
            url: String,
            routing_client_name: String,
            routing_client_secret: String,
          },

          route_services_enabled: bool,
          volume_services_enabled: bool,

          reserved_private_domains: String,

          security_event_logging: {
            enabled: bool
          },

          bits_service: {
            enabled: bool,
            optional(:public_endpoint) => String,
            optional(:private_endpoint) => String,
            optional(:username) => String,
            optional(:password) => String,
          },

          rate_limiter: {
            enabled: bool,
            :general_limit => Integer,
            :unauthenticated_limit => Integer,
            :reset_interval_in_minutes => Integer,
          },

          diego: {
            bbs: {
              url: String,
              ca_file: String,
              cert_file: String,
              key_file: String,
            },
            cc_uploader_url: String,
            file_server_url: String,
            lifecycle_bundles: Hash,
            nsync_url: String,
            pid_limit: Integer,
            stager_url: String,
            temporary_local_staging: bool,
            temporary_local_tasks: bool,
            temporary_local_apps: bool,
            temporary_local_sync: bool,
            temporary_local_tps: bool,
            temporary_cc_uploader_mtls: bool,
            temporary_droplet_download_mtls: bool,
            :temporary_oci_buildpack_mode => enum('oci-phase-1'),
            tps_url: String,
            use_privileged_containers_for_running: bool,
            use_privileged_containers_for_staging: bool,
            :insecure_docker_registry_list => [String],
            :docker_staging_stack => String,
          },

          perform_blob_cleanup: bool,

          development_mode: bool,

          external_host: String,

          default_app_ssh_access: bool,
          default_app_memory: Integer,
          default_app_disk_in_mb: Integer,
          instance_file_descriptor_limit: Integer,
          maximum_app_disk_in_mb: Integer,

          statsd_host: String,
          statsd_port: Integer,
          system_hostnames: [String],

          diego_sync: { frequency_in_seconds: Integer },
          expired_blob_cleanup: { cutoff_age_in_days: Integer },
          expired_orphaned_blob_cleanup: { cutoff_age_in_days: Integer },
          expired_resource_cleanup: { cutoff_age_in_days: Integer },
          orphaned_blobs_cleanup: { cutoff_age_in_days: Integer },
          pending_builds: {
            expiration_in_seconds: Integer,
            frequency_in_seconds: Integer,
          },
          pending_droplets: {
            expiration_in_seconds: Integer,
            frequency_in_seconds: Integer,
          },
          pollable_job_cleanup: { cutoff_age_in_days: Integer },
          service_usage_events: { cutoff_age_in_days: Integer },

          jobs: {
            global: { timeout_in_seconds: Integer },
            optional(:app_usage_events_cleanup) => { timeout_in_seconds: Integer },
            optional(:blobstore_delete) => { timeout_in_seconds: Integer },
            optional(:diego_sync) => { timeout_in_seconds: Integer },
          }
        }
      end
      # rubocop:enable Metrics/BlockLength

      class << self
        def configure_components(config)
          ;
        end
      end
    end
  end
end
