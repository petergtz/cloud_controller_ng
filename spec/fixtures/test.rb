require 'zip'
require 'pry'
require 'open3'

destination_folder = '/Users/pivotal/zips/'
source_zip         = ARGV[0]
zip_to_modify      = File.join(destination_folder, 'result.zip')
#
# Zip::File.open(zip_to_modify, ::Zip::File::CREATE) do |out_zip|
#   Zip::File.open(source_zip) do |in_zip|
#     in_zip.each do |entry|
#       if entry.name[-1] == '/'
#         out_zip.mkdir(entry.name, entry.unix_perms)
#       else
#         entry.get_input_stream do |input_stream|
#           out_zip.get_output_stream(entry, entry.unix_perms) do |output_stream|
#             output_stream.write(input_stream.read)
#           end
#         end
#       end
#     end
#   end
#   # binding.pry
# end

Zip::File.open(source_zip) do |in_zip|
  in_zip.each do |entry|
    binding.pry
    puts "Found an entry in zip: #{entry.name}"
  end
end

def fix_zip_subdir_permissions(source_zip, zip_to_modify)
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
          %(zip -d #{Shellwords.escape(zip_to_modify)} #{z.join(" ")}),
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
        %(zip -d #{Shellwords.escape(zip_to_modify)} #{z.join(" ")}),
      )

      unless status.success?
        raise "potato: SPECIAL Could not remove the directories from\n STDOUT: \"#{stdout}\"\n STDERR: \"#{error}\""
      end
    end
  end
end
