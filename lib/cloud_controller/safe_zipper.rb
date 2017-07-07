require 'find'
require 'open3'
require 'shellwords'
require 'zip'

class SafeZipper
  def self.zip(root_path, zip_output)
    new(root_path, zip_output).zip!
  end

  def self.unzip_for_blobstore(source_zip, destination_dir)
    output, error, status = Open3.capture3(
      %(unzip -qq -n #{Shellwords.escape(source_zip)} -d #{Shellwords.escape(destination_dir)})
    )

    unless status.success?
      raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid',
        "Unzipping had errors\n STDOUT: \"#{output}\"\n STDERR: \"#{error}\"")
    end
  end

  def self.append_cached_resources(source_zip, additional_contents_dir, destination_zip)
    FileUtils.cp(source_zip, destination_zip)

    SafeZipper.new(source_zip, '').valid?

    unless empty_directory?(additional_contents_dir)
      stdout, error, status = Open3.capture3(
        %(zip -q -r --symlinks #{Shellwords.escape(destination_zip)} .),
        chdir: additional_contents_dir,
      )

      unless status.success?
        raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid',
          "Could not zip the package\n STDOUT: \"#{stdout}\"\n STDERR: \"#{error}\"")
      end
    end

    destination_zip
  end

  def self.fix_zip_subdir_permissions(source_zip, destination_zip)
    dirs_to_remove = []
    Zip::File.open(source_zip) do |in_zip|
      in_zip.each do |entry|
        if entry.name[-1] == '/'
          dirs_to_remove << entry.name
        end
      end
    end

    unless dirs_to_remove.empty?
      i = 0
      z = []
      dirs_to_remove.each do |d|
        i = i + 1
        z << d

        if i > 10
          stdout, error, status = Open3.capture3(
            %(zip -d #{Shellwords.escape(destination_zip)} #{z.join(" ")}),
          )

          unless status.success?
            raise "potato: Could not remove the directories from\n STDOUT: \"#{stdout}\"\n STDERR: \"#{error}\""
          end
          i = 0
          z = []
        end
      end

      unless z.empty?
        stdout, error, status = Open3.capture3(
          %(zip -d #{Shellwords.escape(destination_zip)} #{z.join(" ")}),
        )

        unless status.success?
          raise "potato: SPECIAL Could not remove the directories from\n STDOUT: \"#{stdout}\"\n STDERR: \"#{error}\""
        end
      end
    end
  end

  def initialize(zip_path, zip_destination)
    @zip_path        = File.expand_path(zip_path)
    @zip_destination = File.expand_path(zip_destination)
  end

  def zip!
    raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid', 'Path does not exist') unless File.exist?(@zip_path)
    raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid', 'Path does not exist') unless File.exist?(File.dirname(@zip_destination))

    zip
  end

  def valid?
    zip_info
  end

  def size
    @size ||= zip_info.split("\n").last.match(/\A\s*(\d+)/)[1].to_i
  end

  private

  def self.empty_directory?(additional)
    (Dir.entries(additional) - %w(.. .)).empty?
  end

  def zip
    @zip ||= begin
      output, error, status = Open3.capture3(
        %(zip -q -r --symlinks #{Shellwords.escape(@zip_destination)} .),
        chdir: @zip_path
      )

      unless status.success?
        raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid',
          "Could not zip the package\n STDOUT: \"#{output}\"\n STDERR: \"#{error}\"")
      end

      output
    end
  end

  def zip_info
    @zip_info ||= begin
      output, error, status = Open3.capture3(%(unzip -l #{Shellwords.escape(@zip_path)}))

      unless status.success?
        raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid',
          "Unzipping had errors\n STDOUT: \"#{output}\"\n STDERR: \"#{error}\"")
      end

      output
    end
  end
end
