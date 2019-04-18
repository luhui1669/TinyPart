#  podfile_maker.rb
#  
#  Copyright 2019 Yao Li <yaoli@YaodeMacBook-Pro.local>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#  
#  

require './git_repository'

class PodTarget
  attr_accessor :name, :repositories
 def initialize(name)
  self.name = name
  self.repositories = []
 end
end

class PodRepository
  attr_accessor :name, :subspecs, :git_address, :tag, :version, :configurations, :commit
  
  def initialize(name)
    self.name = name
  end
end

class PodfileMaker
  TOP_LEVEL_POD = {
                  'fellow' => 'git@gitlab.corp.cootek.com:dialer_ios/fellow.git',
                  'bbsdk' => 'git@gitlab.corp.cootek.com:dialer_ios/bibi.git', 
                  'wallstreet' => 'git@gitlab.corp.cootek.com:dialer_ios/wallstreet.git', 
                  'TPFeeds' => 'git@gitlab.corp.cootek.com:news_feeds/TPFeeds.git',
                  'TPVTMagic' => 'https://gitlab.corp.cootek.com/dialer_ios_3rdPartyLibs/TPVTMagic.git'
                  }.freeze

  def initialize(url)
    @url = url
  end
  
  def make_podfile()
    targets = generate_pod_repositories_from_local()
    targets = update_podfile_from_remote(targets)
    podfile_content = generate_podfile(targets.first.repositories)
    
    #~ p targets
    puts podfile_content
  end
  
  private
  
  def generate_podfile(pod_repositories)
    podfile = File.open(@url, 'a+')
    
    content = ''
    pod_repositories.each do |pod|
      name = pod.name
      if !name
        next
      end
      line = "pod '%s'" % name
      
      if pod.subspecs
        subspecs = ", :subspecs=>[%s]" % [pod.subspecs]
        line << subspecs
      end
      
      if pod.version
        version = ", '%s'" % [pod.version]
        line << version
      end
      
      if pod.git_address
        git_address = ", :git=>'%s'" % [pod.git_address]
        line << git_address
      end
      
      if pod.configurations
        configurations = ", :configurations=>[%s]" % [pod.configurations]
        line << configurations
      end
      
      if pod.tag
        tag = ", :tag=>'%s'" % [pod.tag]
        line << tag
      end
      
      if pod.commit
        commit = ", :commit=>'%s'" % [pod.commit]
        line << commit
      end
      line << "\n"      
      content << line
    end
    podfile.close()
    
    return content
  end
  
  # return [PodTarget]
  def update_podfile_from_remote(pod_targets)
    pod_targets.each do |target|
      target.repositories.each do |pod|
      git_address = TOP_LEVEL_POD[pod.name]
  
      if !git_address
        next 
      end
      
      repository = GitRepository.new(git_address)
      pod.tag = repository.latest_tag()
      end
    end
    return pod_targets
  end
  
  # return [PodTarget]
  def generate_pod_repositories_from_local()
    podfile = File.open(@url, 'a+')
    
    pod_targets = []
    
    podfile.each_line do |line|
      line.chomp!
      line = line.delete(" \t\r\n") # 去掉空格
      
      if /^#|^=begin/ =~ line ||  # 去掉注释行和空行
        line.length == 0
        next
      end
      
      if /^target:([\w]+do)/ =~ line
        target_name = $1
        pod_targets.push(PodTarget.new(target_name))
      elsif /^abstract_target:([\w]+do)/ =~ line
        target_name = $1
        pod_targets.push(PodTarget.new(target_name))
      end
      
      pod_repository = nil
      
      if /^pod'([\w|-]+)',/ =~ line
        pod_repository = PodRepository.new($1)
      else
        next
      end
    
      if /,'([0-9.~>]+)'/ =~ line
        pod_repository.version = $1
      end

      if /:subspecs=>\[([\w'",]+)\]/ =~ line
        pod_repository.subspecs = $1
      end
      
      if /:configurations=>\[([\w'",]+)\]/ =~ line
        pod_repository.configurations = $1
      end
      
      if /:git=>'([\.\w\/@_:]+)'/ =~ line
        pod_repository.git_address = $1
      end
      
      if /:tag=>'([0-9\.\w\-]+)'/ =~ line
        pod_repository.tag = $1
      end
      
      if (/:commit=>'(.+)'/ =~ line)
        pod_repository.commit = $1
      end
      
      pod_targets.last.repositories.push(pod_repository)
      
    end
    podfile.close()
    return pod_targets
  end
  
end

maker = PodfileMaker.new('/Users/yaoli/Desktop/dialer/Podfile')
maker.make_podfile()
