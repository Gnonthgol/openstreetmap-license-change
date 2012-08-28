require './user'
require './changeset'
require './osm'
require './osm_parse'
require './osm_print'
require 'set'
require 'oauth'
require 'yaml'
require 'net/http'

class API_DB
  attr_accessor :edit_whitelist, :edit_blacklist

  def initialize(site, elements, changesets)
    @server = site

    @max_retries = 3

    @elements = Hash.new
    [OSM::Node, OSM::Way, OSM::Relation].each {|klass| @elements[klass] = Hash.new(Set.new)}

    elements.each do |obj|
      @elements[obj.class][obj.element_id] = Set.new if !@elements[obj.class].include? obj.element_id
      @elements[obj.class][obj.element_id] << obj.version
    end

    @changesets = changesets.to_set

    @edit_whitelist = Array.new
    @edit_blacklist = Array.new
  end

  def each_node(&block)
    @elements[OSM::Node].keys.each &block
  end

  def each_way(&block)
    @elements[OSM::Way].keys.each &block
  end

  def each_relation(&block)
    @elements[OSM::Relation].keys.each &block
  end

  def node(id)
    OSM::parse api_call_get "node/#{id}/history"
  end

  def way(id)
    OSM::parse api_call_get "way/#{id}/history"
  end

  def relation(id)
    OSM::parse api_call_get "relation/#{id}/history"
  end

  def exclude?(klass, i)
    false
  end

  def changeset(id)
    Changeset[User[!(@changesets.include? id)]]
  end

  def objects_using(klass, id)
    ret = []
    name = if klass == OSM::Node
      'node'
    elsif klass == OSM::Way
      'way'
    elsif klass == OSM::Relation
      'relation'
    end
    if name == "node" 
      ret += (OSM::parse api_call_get "node/#{id}/ways")
    end
    ret +=  (OSM::parse api_call_get "#{name}/#{id}/relations")
    return ret
  end

  private
  def api_call_get(path)
    tries = 0
    loop do
      begin
        uri = URI("#{@server}/api/0.6/#{path}")
        puts "GET: #{uri}"
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 320
        
        response = http.request_get(uri.request_uri)
        raise "FAIL: #{uri} => #{response.code}:\n#{response.body}" unless response.code == '200'
        
        return response.body
      rescue Exception => ex
        if tries > @max_retries
          raise
        else
          puts "Got exception: #{ex}, retrying."
        end
      end
      
      tries += 1
    end
  end

end
