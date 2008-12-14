require 'rubygems'
require 'hpricot'
require 'net/https'
require 'uri'
require 'cgi'

##
# Pivotal Tracker API Ruby Wrapper
##

class Tracker
  
  def initialize(project_id = '123', token = '45a6a078f67d9210d2fba91f8c484e7b', ssl=true)
    @project_id, @token, @ssl = project_id, token, ssl
    protocol = @ssl ? 'https' : 'http'
    port     = @ssl ? '443'   : '80'
    @base_url = "#{protocol}://www.pivotaltracker.com:#{port}/services/v1/projects"
  end
  
  def project
    resource_uri = URI.parse("#{@base_url}/#{@project_id}")
   
    response = net_http(resource_uri).start do |http|
      http.get(resource_uri.path, {'Token' => @token})
    end
    validate_response(response.body)
    doc = Hpricot(response.body).at('project')
    { :name             => doc.at('name').innerHTML,
      :iteration_length => doc.at('iteration_length').innerHTML,
      :week_start_day   => doc.at('week_start_day').innerHTML,
      :point_scale      => doc.at('point_scale').innerHTML
    }
  end
  
  def stories
    resource_uri = URI.parse("#{@base_url}/#{@project_id}/stories")
    response = net_http(resource_uri).start do |http|
      http.get(resource_uri.path, {'Token' => @token})
    end
    validate_response(response.body)
    
    doc = Hpricot(response.body)
    
    @stories = []
    
    doc.search('stories > story').each do |story|
      @stories << {
        :id   => story.at('id').innerHTML.to_i,
        :type => story.at('story_type').innerHTML,
        :name => story.at('name').innerHTML
      }
    end
    @stories
  end
  
  # would ideally like to pass a size, aka :all to limit search
  def find(filters = {})
    uri = "#{@base_url}/#{@project_id}/stories"
    unless filters.empty?
      uri << "?filter=" 
      filters.each do |key, value|
        uri << CGI::escape("#{key}:\"#{value}\"")
      end
    end
    
    resource_uri = URI.parse(uri)
    response = net_http(resource_uri).start do |http|
      http.get(resource_uri.path, {'Token' => @token})
    end
    validate_response(response.body)
    
    doc = Hpricot(response.body)
    
    @stories = []
    
    doc.search('stories > story').each do |story|
      @stories << {
        :id   => story.at('id').innerHTML.to_i,
        :type => story.at('story_type').innerHTML,
        :name => story.at('name').innerHTML
      }
    end
    @stories
  end
  
  def find_story(id)
    resource_uri = URI.parse("#{@base_url}/#{@project_id}/stories/#{id}")
    response = net_http(resource_uri).start do |http|
      http.get(resource_uri.path, {'Token' => @token, 'Content-Type' => 'application/xml'})
    end
    validate_response(response.body)
    story_xml_to_hash(response.body)
  end
  
  def create_story(story)
    story_xml = build_story_xml(story)
    resource_uri = URI.parse("#{@base_url}/#{@project_id}/stories")
    response = net_http(resource_uri).start do |http|
      http.post(resource_uri.path, story_xml, {'Token' => @token, 'Content-Type' => 'application/xml'})
    end
    validate_response(response.body)
    story_xml_to_hash(response.body)
  end
  
  def update_story(story)
    story_xml = build_story_xml(story)
    resource_uri = URI.parse("#{@base_url}/#{@project_id}/stories/#{story[:id]}")
    response = net_http(resource_uri).start do |http|
      http.put(resource_uri.path, story_xml, {'Token' => @token, 'Content-Type' => 'application/xml'})
    end
    validate_response(response.body)
    story_xml_to_hash(response.body)
  end
  
  def delete_story(story_id)
    resource_uri = URI.parse("#{@base_url}/#{@project_id}/stories/#{story_id}")
    response = net_http(resource_uri).start do |http|
      http.delete(resource_uri.path, {'Token' => @token})
    end
    validate_response(response.body)
    story_id
  end
  
  def add_comment(story_id, text)
    resource_uri = URI.parse("#{@base_url}/#{@project_id}/stories/#{story_id}/notes")
    comment_xml = "<note><text>#{text}</text></note>"
    response = net_http(resource_uri).start do |http|
      http.post(resource_uri.path, comment_xml, {'Token' => @token, 'Content-Type' => 'application/xml'})
    end
    validate_response(response.body)
    doc = Hpricot(response.body).at('note')
    { :id     => doc.at('id').innerHTML.to_i,
      :text   => doc.at('text').innerHTML,
      :author => doc.at('author').innerHTML,
      :date   => doc.at('date').innerHTML    }
  end
  
private
    
  def build_story_xml(story)
    story_xml = "<story>"
    story.each do |key, value|
      story_xml << "<#{key}>#{remove_xml_tags(value.to_s)}</#{key}>"
    end
    story_xml << "</story>"
  end

  def validate_response(body)
    response = Hpricot(body).at('response')
    if response[:success]=='false'      
      raise TrackerException.new((response/'message').innerHTML)
    end
  end

  def remove_xml_tags(xml)
    xml.gsub(/<\/?[^>]*>/, "")
  end

  def net_http(uri)
    h = Net::HTTP.new(uri.host, uri.port)
    h.use_ssl = @ssl
    h
  end

  def story_xml_to_hash(xml)
    doc = Hpricot(xml).at('story')
    { :id            => doc.at('id').innerHTML.to_i,
      :story_type    => doc.at('story_type').innerHTML,
      :name          => doc.at('name').innerHTML,
      :estimate      => doc.at('estimate').innerHTML,
      :current_state => doc.at('current_state').innerHTML,
      :description   => doc.at('description').innerHTML,
      :url           => doc.at('url').innerHTML
      :requested_by  => doc.at('requested_by').innerHTML.to_i,
      :created_at    => doc.at('created_at').innerHTML.to_i
    }      
  end

end

class TrackerException < Exception  
end
