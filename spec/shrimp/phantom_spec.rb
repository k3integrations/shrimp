#encoding: UTF-8
require 'spec_helper'

Shrimp.configure do |config|
  config.rendering_time = 1000
end

describe Shrimp::Phantom do
  before do
    Shrimp.configure do |config|
      config.rendering_time = 1000
    end
  end

  it "should initialize attributes" do
    phantom = Shrimp::Phantom.new("file://#{test_file}", { :margin => "2cm" }, { }, "#{tmpdir}/test.pdf")
    phantom.source.to_s.should eq "file://#{test_file}"
    phantom.options[:margin].should eq "2cm"
    phantom.outfile.should eq "#{tmpdir}/test.pdf"
  end

  it "should render a pdf file" do
    phantom = Shrimp::Phantom.new("file://#{test_file}")
    phantom.to_pdf("#{tmpdir}/test.pdf").should eq "#{tmpdir}/test.pdf"
    phantom.result.should include "rendered to: #{tmpdir}/test.pdf"
  end

  it "should accept a local file url" do
    phantom = Shrimp::Phantom.new("file://#{test_file}")
    phantom.source.should be_url
  end

  it "should accept a URL as source" do
    phantom = Shrimp::Phantom.new("http://google.com")
    phantom.source.should be_url
  end

  describe '#cmd' do
    it "should generate the correct cmd" do
      phantom = Shrimp::Phantom.new("file://#{test_file}", { :margin => "2cm" }, { }, "#{tmpdir}/test.pdf")
      phantom.cmd.should include "test.pdf A4 1 2cm portrait"
      phantom.cmd.should include "file://#{test_file}"
      phantom.cmd.should include "lib/shrimp/rasterize.js"
    end

    it "cmd should escape the args" do
      phantom = Shrimp::Phantom.new("http://example.com/?something")
      phantom.cmd_array.should include "http://example.com/?something"
      phantom.cmd.      should include "http://example.com/\\?something"

      phantom = Shrimp::Phantom.new("http://example.com/path/file.html?width=100&height=100")
      phantom.cmd_array.should include "http://example.com/path/file.html?width=100&height=100"
      phantom.cmd.      should include "http://example.com/path/file.html\\?width\\=100\\&height\\=100"
    end
  end

  context "rendering to a file" do
    before(:all) do
      phantom = Shrimp::Phantom.new("file://#{test_file}", { :margin => "2cm" }, { }, "#{tmpdir}/test.pdf")
      @result = phantom.to_file
    end

    it "should return a File" do
      @result.should be_a File
    end

    it "should be a valid pdf" do
      valid_pdf?(@result).should eq true
      pdf_strings(@result).should eq "Hello\tWorld!"
    end
  end

  context "rendering to a pdf" do
    before(:all) do
      @phantom = Shrimp::Phantom.new("file://#{test_file}", { :margin => "2cm" }, { })
      @result  = @phantom.to_pdf("#{tmpdir}/test.pdf")
    end

    it "should return a path to pdf" do
      @result.should be_a String
      @result.should eq "#{tmpdir}/test.pdf"
    end

    it "should be a valid pdf" do
      valid_pdf?(@result).should eq true
      pdf_strings(Pathname(@result)).should eq "Hello\tWorld!"
    end
  end

  context "rendering to a String" do
    before(:all) do
      phantom = Shrimp::Phantom.new("file://#{test_file}", { :margin => "2cm" }, { })
      @result = phantom.to_string("#{tmpdir}/test.pdf")
    end

    it "should return the File IO String" do
      @result.should be_a String
    end

    it "should be a valid pdf" do
      valid_pdf?(@result).should eq true
      pdf_strings(@result).should eq "Hello\tWorld!"
    end
  end

  context "Errors" do
    describe "'Unable to load the address' error" do
      before { @result = phantom.run }

      context 'an invalid http: address' do
        subject(:phantom) { Shrimp::Phantom.new("http://example.com/foo/bar") }
        it { @result.should be_nil }
        its(:error)                 { should eq "404 Unable to load the address!" }
        its(:page_load_error?)      { should eq true }
        its(:page_load_status_code) { should eq 404 }
      end

      context 'an http: response that redirects' do
        around(:each) do |example|
          with_local_server do |server|
            server.mount_proc '/' do |request, response|
              response.body = 'Home'
              raise WEBrick::HTTPStatus::OK
            end
            server.mount_proc '/redirect_me' do |request, response|
              response['Location'] = '/'
              raise WEBrick::HTTPStatus::Found
            end
            example.run
          end
        end
        subject(:phantom) { Shrimp::Phantom.new("http://#{local_server_host}/redirect_me") }
        it { @result.should be_nil }
        its(:error)                 { should eq "302 Unable to load the address!" }
        its(:page_load_error?)      { should eq true }
        its(:page_load_status_code) { should eq 302 }
        its('response.keys') { should include 'redirectURL' }
        its('response_headers.keys') { should == ['Location', 'Server', 'Date', 'Content-Length', 'Connection'] }
        its(:redirect_to) { should eq "http://#{local_server_host}/" }
      end

      context 'an invalid file: address' do
        subject(:phantom) { Shrimp::Phantom.new("file:///foo/bar") }
        it { @result.should be_nil }
        its(:error)                 { should eq "null Unable to load the address!" }
        its(:page_load_error?)      { should eq true }
        its(:page_load_status_code) { should eq 'null' }
      end
    end
  end

  context "Errors (using bang methods)" do

    it "should be unable to load the address" do
      phantom = Shrimp::Phantom.new("file:///foo/bar")
      expect { phantom.run! }.to raise_error Shrimp::RenderingError
    end
  end

  context 'test_file_with_page_numbers.html' do
    let(:test_file) { super('test_file_with_page_numbers.html') }

    before do
      phantom = Shrimp::Phantom.new("file://#{test_file}")
      @result = phantom.to_string("#{tmpdir}/test.pdf")
    end

    it "PDF should contain page numbers" do
      pdf_strings(@result).should eq "Header:\tPage\t1/2Footer:\tPage\t1/2Hello\tWorld!Hello\tWorld!Header:\tPage\t2/2Footer:\tPage\t2/2"
    end
  end
end
