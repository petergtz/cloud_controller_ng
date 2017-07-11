require 'spec_helper'
require 'cloud_controller/app_packager'

RSpec.describe AppPackager do
  around do |example|
    Dir.mktmpdir('app_packager_spec') do |tmpdir|
      @tmpdir = tmpdir
      example.call
    end
  end

  subject(:app_packager) { AppPackager.new(input_zip) }

  describe '#size' do
    let(:input_zip) { File.join(Paths::FIXTURES, 'good.zip') }
    let(:size_of_good_zip) { 17 }

    it 'returns the sum of each file size' do
      expect(app_packager.size).to eq(size_of_good_zip)
    end
  end

  describe '#unzip' do
    let(:input_zip) { File.join(Paths::FIXTURES, 'good.zip') }

    it 'unzips the file given' do
      app_packager.unzip(@tmpdir)

      expect(Dir["#{@tmpdir}/**/*"].size).to eq 4
      expect(Dir["#{@tmpdir}/*"].size).to eq 3
      expect(Dir["#{@tmpdir}/subdir/*"].size).to eq 1
    end

    context 'when the zip destination does not exist' do
      it 'raises an exception' do
        expect {
          app_packager.unzip(File.join(@tmpdir, 'blahblah'))
        }.to raise_exception(CloudController::Errors::ApiError, /destination does not exist/i)
      end
    end

    context 'when zip does not exist' do
      let(:input_zip) { 'missing_zip' }

      it 'raises an exception' do
        expect {
          app_packager.unzip(@tmpdir)
        }.to raise_exception(CloudController::Errors::ApiError, /Zip not found/i)
      end
    end

    context 'when the zip is empty' do
      let(:input_zip) { File.join(Paths::FIXTURES, 'empty.zip') }

      it 'raises an exception' do
        expect {
          app_packager.unzip(@tmpdir)
        }.to raise_exception(CloudController::Errors::ApiError, /zipfile is empty/)
      end
    end

    context 'when the zip contains a symlink that does not leave the root dir' do
      let(:input_zip) { File.join(Paths::FIXTURES, 'good_symlinks.zip') }

      it 'unzips them correctly without errors' do
        app_packager.unzip(@tmpdir)
        expect(File.symlink?("#{@tmpdir}/what")).to be true
      end
    end

    context 'when the zip contains a symlink pointing to a file out of the root dir' do
      let(:input_zip) { File.join(Paths::FIXTURES, 'bad_symlinks.zip') }

      it 'raises an exception' do
        expect { app_packager.unzip(@tmpdir) }.to raise_exception(CloudController::Errors::ApiError, /symlink.+outside/i)
      end
    end
  end

  describe '#append_dir_contents' do
    let(:input_zip) { File.join(@tmpdir, 'good.zip') }
    let(:additional_files_path) { File.join(Paths::FIXTURES, 'fake_package') }

    before { FileUtils.cp(File.join(Paths::FIXTURES, 'good.zip'), input_zip) }

    it 'adds the files to the zip' do
      app_packager.append_dir_contents(additional_files_path)

      output = `zipinfo #{input_zip}`

      expect(output).not_to include './'
      expect(output).not_to include 'fake_package'

      expect(output).to match /^l.+coming_from_inside$/
      expect(output).to include 'here.txt'
      expect(output).to include 'subdir/'
      expect(output).to include 'subdir/there.txt'

      expect(output).to include 'bye'
      expect(output).to include 'hi'
      expect(output).to include 'subdir/'
      expect(output).to include 'subdir/greetings'

      expect(output).to include '7 files'
    end

    context 'when there are no additional files' do
      let(:additional_files_path) { File.join(@tmpdir, 'empty') }

      it 'results in the existing zip' do
        Dir.mkdir(additional_files_path)
        app_packager.append_dir_contents(additional_files_path)

        output = `zipinfo #{input_zip}`

        expect(output).to include 'bye'
        expect(output).to include 'hi'
        expect(output).to include 'subdir/'
        expect(output).to include 'subdir/greeting'

        expect(output).to include '4 files'
      end
    end
  end

  describe '#fix_subdir_permissions' do
    let(:input_zip) { File.join(@tmpdir, 'many_dirs.zip') }

    before { FileUtils.cp(File.join(Paths::FIXTURES, 'app_packager_zips', 'many_dirs.zip'), input_zip) }

    it 'removes directory entries' do
      app_packager.fix_subdir_permissions

      output = `zipinfo #{input_zip}`

      expect(output).to include 'empty_root_file_1'
      expect(output).to include 'empty_root_file_2'

      (0..20).each do |i|
        expect(output).to include("folder_#{i}/empty_file")
      end

      expect(output).to include '23 files'
    end
  end
end
