#  git_utils.rb
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

require 'git'

class GitRepository
	def initialize(url)
		@url = url
		@g = Git.ls_remote(url)
	end
	
	def tags()
		return @g['tags']
	end
	
	def latest_tag()
		ts = self.tags().keys
		versions = []
		ts.each do |tag|
			/(^[0-9\.]+\-dev\-[0-9]+)/ =~ tag
			versions.push($1)
			
			/(^[0-9]+\.[0-9\.]+)$/ =~ tag
			versions.push($1)
		end
		versions.compact!
		versions.uniq!
		versions = versions.sort! do |a, b|
			temp_a = '' + a
			temp_b = '' + b
			if !a.include?('dev')	# 如果tag中不包含'dev'，那么就是当前版本号下优先级最高的
				temp_a << '-dev-99999'
			end
			if !b.include?('dev')
				temp_b << '-dev-99999'
			end
			temp_a = temp_a.gsub(/\-dev\-/, '.')
			temp_b = temp_b.gsub(/\-dev\-/, '.')
			array_a = temp_a.split(/\./)
			array_b = temp_b.split(/\./)
			
			if array_a[0] != array_b[0]
				array_b[0].to_i <=> array_a[0].to_i
			elsif array_a[1] != array_b[1]
				array_b[1].to_i <=> array_a[1].to_i
			elsif array_a[2] != array_b[2]
				array_b[2].to_i <=> array_a[2].to_i
			elsif array_a[3] != array_b[3]
				array_b[3].to_i <=> array_a[3].to_i
			else
				a <=> b
			end
		end
		return versions[0]
	end
end

#~ repository = GitRepository.new('git@gitlab.corp.cootek.com:dialer_ios/wallstreet.git')
#~ p repository.latest_tag()
