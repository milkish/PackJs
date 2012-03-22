require 'yaml'
require 'json'
require 'sinatra/base'
require 'aws/s3'
require 'haml'
require 'zlib'

## Config
PACKJS_ENV = ENV["PACKJS_ENV"] || "development"

# aws
s3Config = YAML.load_file('secrets/amazon.yaml')
AWS_ACCESS_KEY_ID     = s3Config["access_key_id"] 
AWS_SECRET_ACCESS_KEY = s3Config["secret_access_key"]
AWS_BUCKET_NAME       = s3Config["bucket_name"]

# load the libs data and master sort into memory
JS_LIBS = YAML.load_file "jsfiles.yaml"
JS_SORT = JSON.load File.open("jssort.json").read

# cache header values
LAST_MODIFIED = Time.now            # when the server starts
ETAG          = LAST_MODIFIED.to_i  # same for every request

# pack settings
MAX_LIBS = 6
VERSION_SEPARATOR = "-"

## Main App
class PackJs < Sinatra::Base
  include AWS::S3

  # caches the url to known packs
  @@known_packs_cache = {}

  # before every request we make sure
  # we're still connected to s3 and set
  # the cache headers
  before { 
    s3_connect if not Base.connected?
    record_metrics request
    last_modified LAST_MODIFIED
    etag  ETAG
  }

  ## Routes

  ### Homepage
  get '/' do
    render_template :index
  end

  ### get lib
  get '/:libs_key' do |libs_key|
    # check the cache for the lib and
    # auto redirect if found
    return to_cdn @@known_packs_cache[libs_key] if @@known_packs_cache[libs_key]

    # if not found, on to validation

    # split the lib_keys string into individual names
    libnames = libs_key.split('+')

    # exit if more than the max allowd libs was requested
    lib_error!( :too_many, libnames.count ) if libnames.count > MAX_LIBS

    # check for duplicate libs
    dup = first_duplicate_lib libnames
    # exit if any
    lib_error!( :duplicate, dup ) if dup

    # loop the libs checking versions
    filenames = libnames.map do |name|
      lib_id, version_id = name.split VERSION_SEPARATOR
      lib_error!(:not_found, lib_id) unless JS_LIBS[lib_id]

      # if no version specified, grab the latest
      if version_id.nil?
        version_id = JS_LIBS[lib_id]["versions"].first[0]
      else
        lib_error!(:wrong_version, name) unless JS_LIBS[lib_id]["versions"][version_id]
      end

      "%s%s%s" % [lib_id,VERSION_SEPARATOR,version_id]
    end

    # sort the libs according to the master sort
    filenames = sort_libs filenames

    # at thist point, we're done validating and
    # organizing the requested libs. Now we 
    # work with amazon.

    # create the amazon filename
    s3_filename = (filenames * "+") + ".js"
    # build the url. this doesn't verify with amazon. It
    # returns a url regardless of whether the file really
    # exists or not.
    amazon_url = S3Object.url_for(s3_filename, AWS_BUCKET_NAME,  :authenticated => false)
    # so we check if it exists, and if not build the pack
    if not S3Object.exists? s3_filename, AWS_BUCKET_NAME
      pack = ""
      # concat all the libs, seperated by a new line, into
      # one string
      filenames.each do |filename|
        File.open "jsfiles/#{filename}.js", "r" do |f|
          pack << f.read
          pack << "\n"
        end
      end
      # write the pack to disc
      orig = "/tmp/#{s3_filename}.raw"
      File.open(orig, "w") { |f| f.write pack }
      # gzip the pack
      Zlib::GzipWriter.open("/tmp/#{s3_filename}") do |gz|
        gz.mtime = File.mtime(orig)
        gz.orig_name = orig
        gz.write IO.read(orig)
        gz.close
      end
      # upload it to s3
      S3Object.store(
        s3_filename,
        open("/tmp/#{s3_filename}"),
        AWS_BUCKET_NAME,
        :access => :public_read,
        :content_type => 'application/x-javascript',
        :content_encoding => 'gzip'
      )
    end
    # cache the key for a speedy lookup next time
    @@known_packs_cache[libs_key] = amazon_url
    # finally redirect to amazon
    to_cdn amazon_url
  end

  ## Utils

  ### S3 Connect
  def s3_connect
    Base.establish_connection!(
      :access_key_id     => AWS_ACCESS_KEY_ID,
      :secret_access_key => AWS_SECRET_ACCESS_KEY
    )
  end

  ### Render Template
  def render_template template_name
    str = haml template_name, :format => :html5
    str.gsub(/(\n|\t)/i,"") if PACKJS_ENV == "production"
    str
  end

  ### to cdn
  def to_cdn url
    redirect to(url), 302
  end

  ### sort libs
  # arrange according to the master sort
  def sort_libs libnames
    sorted = []
    libnames.each do |libname|
      libid = libname.split('-')[0]
      sorted[JS_SORT.index libid] = libname
    end
    sorted.compact
  end

  def version_string num
    num = num.to_s
    str = ""
    offset = num.length % 2
    6.times do |ind|
      str << "." if( ind !=0 and ind % 2 == offset )
      str << num[ind] if( num[ind] != "0" or ind % 2 != offset )
    end
    str.gsub! /\.0$/,""
    print "\nversion number from #{num} to #{str}\n"
    str
  end

  ### first duplicate
  # checks for duplicates regardless of version number
  def first_duplicate_lib libs
    tmp = []
    libs.each do |lib|
      libname = lib.split('-')[0] 
      return libname if tmp.index libname
      tmp.push libname
    end
    nil
  end

  ### lib error
  def lib_error! type, data
    code, msg = 400, "Error: "
    case type
    when :duplicate
      msg << "You requested the #{data} library more than once."
    when :not_found
      code += 4
      msg << "No library named #{data} found."
    when :wrong_version
      code += 4
      lib_id, version_id = data.split VERSION_SEPARATOR
      msg << "Lib version #{data} not found."
      msg << " Available versions for #{lib_id} are: #{JS_LIBS[lib_id]["versions"].keys * ", "}"
    when :too_many
      msg << "You requested #{data} libraries. The max is #{MAX_LIBS}."
    end
    halt code, msg
  end


  ## Metrics
  def record_metrics req
    # Thread.new{
    #   #TODO: record metrics here
    # }
  end
end


