require 'cloud_controller/blobstore/fingerprints_collection'
require 'shellwords'
require 'cloud_controller/safe_zipper'

module CloudController
  module Packager
    class LocalBitsPacker
      def send_package_to_blobstore(blobstore_key, uploaded_package_zip, cached_files_fingerprints)
        matched_resources = CloudController::Blobstore::FingerprintsCollection.new(cached_files_fingerprints)

        FileUtils.chmod('u+w', uploaded_package_zip)

        Dir.mktmpdir('safezipper', tmp_dir) do |root_path|
          workspace = File.join(root_path, 'workspace')
          FileUtils.mkdir(workspace)

          # unzip app contents & upload to blobstore
          app_contents_path = File.join(root_path, 'application_contents')
          SafeZipper.unzip_for_blobstore(uploaded_package_zip, app_contents_path)
          global_app_bits_cache.cp_r_to_blobstore(app_contents_path)

          # download cached resources from blobstore
          matched_resources.each do |local_destination, file_sha, mode|
            global_app_bits_cache.download_from_blobstore(file_sha, File.join(workspace, local_destination), mode: mode)
          end

          # append cached resources to app.zip
          complete_app_zip = File.join(root_path, 'package.zip')
          SafeZipper.append_cached_resources(uploaded_package_zip, workspace, complete_app_zip)

          # fix up zip?
          destination_zip = File.join(root_path, 'final.zip')
          FileUtils.cp(complete_app_zip, destination_zip)
          SafeZipper.fix_zip_subdir_permissions(complete_app_zip, destination_zip)

          validate_size!(destination_zip)

          package_blobstore.cp_to_blobstore(destination_zip, blobstore_key)

          {
            sha1:   Digester.new.digest_path(destination_zip),
            sha256: Digester.new(algorithm: Digest::SHA256).digest_path(destination_zip),
          }
        end
      end

      private

      def validate_size!(uploaded_package_zip)
        return unless max_package_size

        total_size = SafeZipper.new(uploaded_package_zip, '').size
        if total_size > max_package_size
          raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid', "Package may not be larger than #{max_package_size} bytes")
        end
      end

      def tmp_dir
        @tmp_dir ||= VCAP::CloudController::Config.config[:directories][:tmpdir]
      end

      def package_blobstore
        @package_blobstore ||= CloudController::DependencyLocator.instance.package_blobstore
      end

      def global_app_bits_cache
        @global_app_bits_cache ||= CloudController::DependencyLocator.instance.global_app_bits_cache
      end

      def max_package_size
        @max_package_size ||= VCAP::CloudController::Config.config[:packages][:max_package_size] || 512 * 1024 * 1024
      end
    end
  end
end
