require 'find'
require 'open3'
require 'shellwords'
require 'zip'
require 'zip/filesystem'

class AppPackager
  attr_reader :path

  def initialize(zip_path)
    @path = zip_path
  end

  def unzip(destination_dir)
    raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', 'Destination does not exist') unless File.directory?(destination_dir)
    raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', 'Zip not found') unless File.exist?(@path)
    raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', 'Symlink(s) point outside of root folder') if any_outside_symlinks?(destination_dir)

    output, error, status = Open3.capture3(
      %(unzip -qq -n #{Shellwords.escape(@path)} -d #{Shellwords.escape(destination_dir)})
    )

    unless status.success?
      raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid',
        "Unzipping had errors\n STDOUT: \"#{output}\"\n STDERR: \"#{error}\"")
    end
  end

  def append_dir_contents(additional_contents_dir)
    unless empty_directory?(additional_contents_dir)
      stdout, error, status = Open3.capture3(
        %(zip -q -r --symlinks #{Shellwords.escape(@path)} .),
        chdir: additional_contents_dir,
      )

      unless status.success?
        raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid',
          "Could not zip the package\n STDOUT: \"#{stdout}\"\n STDERR: \"#{error}\"")
      end
    end
  end

  # TODO: Add comment on why this exists!!
  def fix_subdir_permissions(destination_zip)
    FileUtils.cp(@path, destination_zip)
    dirs_to_remove = []
    Zip::File.open(@path) do |in_zip|
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
        i += 1
        z << d

        if i > 10
          stdout, error, status = Open3.capture3(
            %(zip -d #{Shellwords.escape(destination_zip)} #{z.join(' ')}),
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
          %(zip -d "#{Shellwords.escape(destination_zip)}" #{z.join(' ')}),
        )

        unless status.success?
          raise "potato: SPECIAL Could not remove the directories from\n STDOUT: \"#{stdout}\"\n STDERR: \"#{error}\""
        end
      end
    end
  rescue Zip::Error => e
    raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', "Invalid zip archive. Error: #{e.message}")
  end

  def size
    size = 0
    Zip::File.open(@path) do |in_zip|
      in_zip.each do |entry|
        size += entry.size
      end
    end

    size
  rescue Zip::Error => e
    raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', "Invalid zip archive. Error: #{e.message}")
  end

  private

  def any_outside_symlinks?(destination_dir)
    Zip::File.open(@path) do |in_zip|
      in_zip.each do |entry|
        if entry.ftype == :symlink
          symlink = in_zip.file.read(entry.name)
          return true unless VCAP::CloudController::FilePathChecker.safe_path?(symlink, destination_dir)
        end
      end
    end

    false
  rescue Zip::Error => e
    raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', "Invalid zip archive. Error: #{e.message}")
  end

  def empty_directory?(dir)
    (Dir.entries(dir) - %w(.. .)).empty?
  end
end
