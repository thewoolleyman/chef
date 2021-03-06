#
# Author:: Daniel DeLeo (<dan@kallistec.com>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require File.expand_path(File.join(File.dirname(__FILE__),"..", "..", "..", "spec_helper"))

describe Chef::Provider::Deploy::Revision do
  
  before do
    Chef::Config[:file_cache_path] = '/tmp/foo'
    @resource = Chef::Resource::Deploy.new("/my/deploy/dir")
    @resource.revision("8a3195bf3efa246f743c5dfa83683201880f935c")
    @node = Chef::Node.new
    @provider = Chef::Provider::Deploy::Revision.new(@node, @resource)
    @provider.load_current_resource
    @runner = mock("runnah", :null_object => true)
    Chef::Runner.stub!(:new).and_return(@runner)
    @expected_release_dir = "/my/deploy/dir/releases/8a3195bf3efa246f743c5dfa83683201880f935c"
  end
  
  after do
    # Make sure we don't keep any state in our tests
    FileUtils.rspec_reset
    FileUtils.rm_rf '/tmp/foo' if File.directory?("/tmp/foo")
  end
  
  
  it "uses the resolved revision from the SCM as the release slug" do
    @provider.scm_provider.stub!(:revision_slug).and_return("uglySlugly")
    @provider.send(:release_slug).should == "uglySlugly"
  end
  
  it "deploys to a dir named after the revision" do
    @provider.release_path.should == @expected_release_dir
  end
  
  it "stores the release dir in the file cache when copying the cached repo" do
    FileUtils.stub!(:mkdir_p)
    @provider.stub!(:run_command).and_return(true)
    @provider.copy_cached_repo
    @provider.stub!(:release_slug).and_return("73219b87e977d9c7ba1aa57e9ad1d88fa91a0ec2")
    @provider.load_current_resource
    @provider.copy_cached_repo
    second_release = "/my/deploy/dir/releases/73219b87e977d9c7ba1aa57e9ad1d88fa91a0ec2"
    
    @provider.all_releases.should == [@expected_release_dir,second_release]
  end
  
  it "removes a release from the file cache when it's used again in another release and append it to the end" do
    FileUtils.stub!(:mkdir_p)
    @provider.stub!(:run_command).and_return(true)
    @provider.copy_cached_repo
    @provider.stub!(:release_slug).and_return("73219b87e977d9c7ba1aa57e9ad1d88fa91a0ec2")
    @provider.load_current_resource
    @provider.copy_cached_repo
    second_release = "/my/deploy/dir/releases/73219b87e977d9c7ba1aa57e9ad1d88fa91a0ec2"
    @provider.all_releases.should == [@expected_release_dir,second_release]
    @provider.copy_cached_repo
    @provider.stub!(:release_slug).and_return("8a3195bf3efa246f743c5dfa83683201880f935c")
    @provider.load_current_resource
    @provider.copy_cached_repo
    @provider.all_releases.should == [second_release, @expected_release_dir]
  end
  
  it "removes a release from the file cache when it's deleted by :cleanup!" do
    %w{first second third fourth fifth latest}.each do |release_name|
      @provider.send(:release_created, release_name)
    end
    @provider.all_releases.should == %w{first second third fourth fifth latest}
    
    FileUtils.stub!(:rm_rf)
    @provider.cleanup!
    @provider.all_releases.should == %w{second third fourth fifth latest}
  end
  
  it "regenerates the file cache if it's not available" do
    oldest = "/my/deploy/dir/releases/oldest"
    latest = "/my/deploy/dir/releases/latest"
    Dir.should_receive(:glob).with("/my/deploy/dir/releases/*").and_return([latest, oldest])
    ::File.should_receive(:ctime).with(oldest).and_return(Time.now - 10)
    ::File.should_receive(:ctime).with(latest).and_return(Time.now - 1)
    @provider.all_releases.should == [oldest, latest]
  end

end