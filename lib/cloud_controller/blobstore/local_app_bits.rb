require 'cloud_controller/safe_zipper'
require 'vcap/digester'

module CloudController
  module Blobstore
    class LocalAppBits
      PACKAGE_NAME = 'package.zip'.freeze
      UNCOMPRESSED_DIR = 'uncompressed'.freeze

      def self.from_compressed_bits(compressed_bits_path, tmp_dir, &block)
        Dir.mktmpdir('safezipper', tmp_dir) do |root_path|
          unzip_path = File.join(root_path, UNCOMPRESSED_DIR)
          FileUtils.mkdir(unzip_path)
          storage_size = 0
          out_root_path = File.join(root_path, 'extracted')
          FileUtils.mkdir(compressed_bits_path, out_root_path) unless File.exists? out_root_path
          if compressed_bits_path && File.exist?(compressed_bits_path)
            FileUtils.cp(compressed_bits_path, root_path)
            storage_size = SafeZipper.unzip(compressed_bits_path, out_root_path)
          end
          block.yield new(out_root_path, storage_size)
        end
      end

      attr_reader :uncompressed_path, :storage_size

      def initialize(root_path, storage_size)
        @root_path = root_path
        @uncompressed_path = File.join(root_path, UNCOMPRESSED_DIR)
        @storage_size = storage_size
      end

      def create_package
        destination = File.join(@root_path, PACKAGE_NAME)
        SafeZipper.zip(uncompressed_path, destination)
        File.new(destination)
      end
    end
  end
end
