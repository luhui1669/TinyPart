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

class PodLock
  attr_accessor :dependency_repositories, :podfile_checksum
  
  def initialize()
    self.dependency_repositories = []
  end
  
  def push_repository(pod_name, version, git_address, tag)
    if pod_name.include?('/')
      pod_name_components = pod_name.split('/')
      pod_name = pod_name_components[0]
      pod_subspecs = pod_name_components[1]
      repository = nil
      self.dependency_repositories.each do |r|
        if pod_name == r.name
          repository = r
          #~ print 'r.name: '+r.name + ', r.pod_name: '+pod_name + "\n"
          break;
        end
      end
      
      if repository
        repository.subspecs.push(pod_subspecs)
      elsif
        repository = PodRepository.new(pod_name)
        repository.subspecs = [pod_subspecs]
        repository.version = version
        repository.tag = tag
        repository.git_address = git_address
        self.dependency_repositories.push(repository)
      end
    elsif
      repository = PodRepository.new(pod_name)
      repository.version = version
      repository.tag = tag
      repository.git_address = git_address
      self.dependency_repositories.push(repository)
    end
  end
end

class PodfileMaker
  attr_accessor :configurations
  
  def initialize(podfile_url, module_configuration_url)
    @podfile_url = podfile_url
    @module_configuration_url = module_configuration_url
    self.configurations = Hash.new()
    eval(File.new(module_configuration_url).read)
  end
  
  def make_podfile()
    targets = generate_pod_repositories_from_podfile()
    podlock = generate_pod_from_podlock()
    targets = auto_update_podfile(targets)
    
    podfile_content = generate_podfile(targets.first.repositories)
    podlock_content = generate_podfile(podlock.dependency_repositories)
    #~ p targets
    #~ puts podfile_content
    puts podlock_content
  end
  
  private
  
  def target(nameKey)
    self.configurations[nameKey] = yield
  end
  
  # return [PodTarget]
  def generate_pod_repositories_from_podfile()
    podfile = File.open(@podfile_url, 'a+')
    
    pod_targets = []
    
    podfile.each_line do |line|
      line.chomp!
      line = line.delete(" \t\r\n") # 去掉空格
      
      if /^#|^=begin/ =~ line ||  # 去掉注释行和空行
        line.length == 0
        next
      end
      
      if /^target:([\w]+)do/ =~ line
        target_name = $1
        pod_targets.push(PodTarget.new(target_name))
      elsif /^abstract_target:([\w]+)do/ =~ line
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
        pod_repository.subspecs = $1.delete('"\'').split(/,/)
      end
      
      if /:configurations=>\[([\w'",]+)\]/ =~ line
        pod_repository.configurations = $1.delete('"\'').split(/,/)
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
  
  # return PodLock
  def generate_pod_from_podlock()
    podlock_url = @podfile_url.gsub(/\/Podfile$/, '/Podfile.lock')
    podlock_file = File.open(podlock_url)
    section_name = nil
    podlock = PodLock.new()
    podlock_file.each_line do |line|
      if /^DEPENDENCIES:$/ =~ line
        section_name = 'DEPENDENCIES'
      elsif /^PODS:$/ =~ line
        section_name = 'PODS'
      elsif /^SPEC REPOS:$/ =~ line
        section_name = 'SPEC '
      elsif /^EXTERNAL SOURCES:$/ =~ line
        section_name = 'EXTERNAL SOURCES'
      elsif /^CHECKOUT OPTIONS:$/ =~ line
        section_name = 'CHECKOUT OPTIONS'
      elsif /^SPEC CHECKSUMS:$/ =~ line
        section_name = 'SPEC CHECKSUMS'
      elsif /^PODFILE CHECKSUM:$/ =~ line
        section_name = 'PODFILE CHECKSUM'
      elsif /^COCOAPODS:$/ =~ line
        section_name = 'COCOAPODS'
      end
      
      if section_name == 'DEPENDENCIES'
        line = line.delete(" \t\r") # 去掉空格
        if /^-([\/\w\-]+)\(=([0-9\.]+)\)/ =~ line
          pod_name = $1
          pod_version = $2
          podlock.push_repository(pod_name, pod_version, nil, nil)
        elsif /^-"([\/\w\-]+)\(from`(.+)`,tag`([0-9\w\.\-]+)`\)"/ =~ line 
          pod_name = $1
          git_address = $2
          tag = $3
          podlock.push_repository(pod_name, nil, git_address, tag)
        end
        
      end
    end
    podlock_file.close()
    return podlock
  end
  
  # return [PodTarget]
  def auto_update_podfile(pod_targets)
    pod_targets.each do |target|
      target_name = target.name
      
      target.repositories.each do |pod|

      if !self.configurations[target_name.to_sym] ||
         !self.configurations[target_name.to_sym][:auto_update].include?(pod.name)
        next 
      end
      
      repository = GitRepository.new(pod.git_address)
      pod.tag = repository.latest_tag()
      end
    end
    return pod_targets
  end
  
  def generate_podfile(pod_repositories)    
    content = ''
    pod_repositories.each do |pod|
      name = pod.name
      if !name
        next
      end
      line = "pod '%s'" % name
      
      if pod.subspecs
        subspecs = ", :subspecs=>%s" % [pod.subspecs.to_s.gsub(/"/, '\'')]
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
        configurations = ", :configurations=>%s" % [pod.configurations.to_s.gsub(/"/, '\'')]
        line << configurations
      end
      
      if pod.tag
        tag = ", :tag=>'%s'" % [pod.tag]
        line << tag
      elsif pod.commit
        commit = ", :commit=>'%s'" % [pod.commit]
        line << commit
      end
      
      line << "\n"      
      content << line
    end
    
    return content
  end
end

maker = PodfileMaker.new('/Users/yaoli/Desktop/dialer/Podfile', '/Users/yaoli/Desktop/dialer/PodModuleConfiguration')
maker.make_podfile()
