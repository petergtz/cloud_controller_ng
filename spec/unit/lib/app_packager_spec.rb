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

        output = `zipinfo #{input_zip}`

        expect(output).to include 'bye'
        expect(output).to include 'hi'
        expect(output).to include 'subdir/'
        expect(output).to include 'subdir/greeting'

        expect(output).to include '4 files'

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
    context 'when there are many directories' do
      let(:input_zip) { File.join(@tmpdir, 'many_dirs.zip') }

      before { FileUtils.cp(File.join(Paths::FIXTURES, 'app_packager_zips', 'many_dirs.zip'), input_zip) }

      it 'batches the directory deletes so it does not exceed the max command length' do
        allow(Open3).to receive(:capture3).and_call_original
        app_packager.fix_subdir_permissions

        output = `zipinfo #{input_zip}`

        (0..20).each do |i|
          expect(output).to include("folder_#{i}/")
          expect(output).to include("folder_#{i}/empty_file")
        end

        expect((21.0 / AppPackager::DIRECTORY_DELETE_BATCH_SIZE).ceil).to eq(3)
        expect(Open3).to have_received(:capture3).exactly(3).times
      end
    end

    context 'when the zip has directories without the directory attribute or execute permission (it was created on windows)' do
      let(:input_zip) { File.join(@tmpdir, 'bad_directory_permissions.zip') }

      before { FileUtils.cp(File.join(Paths::FIXTURES, 'app_packager_zips', 'bad_directory_permissions.zip'), input_zip) }

      it 'adds the directory and execute bits' do
        expect(`zipinfo #{input_zip}`).to match %r(-rw--.*fat.*META-INF/)

        app_packager.fix_subdir_permissions

        expect(`zipinfo #{input_zip}`).to match %r(drwxr-xr-x.*unx.*META-INF/)
      end
    end
  end
end
