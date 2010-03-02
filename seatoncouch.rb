#!/usr/bin/ruby -w

# MIT License
#
# Copyright (c) 2010 Filipe David Borba Manana <fdmanana@gmail.com>
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

$LOAD_PATH.push('json/lib')

require 'getoptlong'
require 'singleton'
require 'net/http'
require 'uri'
require 'json'

module SeatOnCouch

    DEFAULT_DEBUG = false
    DEFAULT_HOST = "localhost"
    DEFAULT_PORT = "5984"
    DEFAULT_DB_COUNT = 10
    DEFAULT_DOC_COUNT = 100
    DEFAULT_USER_COUNT = 10
    DEFAULT_DB_START_ID = 1
    DEFAULT_DOC_START_ID = 1
    DEFAULT_USER_START_ID = 1
    DEFAULT_DB_PREFIX = "testdb"
    DEFAULT_DOC_PREFIX = "doc"
    DEFAULT_USER_PREFIX = "user"
    DEFAULT_DOC_TPL = 'default_doc.tpl'
    DEFAULT_SEC_OBJ = nil
    DEFAULT_RECREATE_DBS = false


    def self.showhelp
        puts <<_EOH_
Usage:  #{File.basename __FILE__} [OPTION]*

  Tool to populate a CouchDB instance with several DBs, docs and users.
  Used for development purposes and measuring CouchDB performance.

Options:

  -h, --help                     Displays this help and exits.

      --debug                    Enable debug mode.

      --host                     Name or address of the CouchDB instance.
                                 Defaults to `#{DEFAULT_HOST}'

      --port                     Port of the CouchDB instance.
                                 Defaults to `#{DEFAULT_PORT}'

      --dbs count                Number of DBs to create.
                                 Defaults to `#{DEFAULT_DB_COUNT}'

      --docs count               Number of docs to create per DB.
                                 Defaults to `#{DEFAULT_DOC_COUNT}'

      --users count              Number of users to create.
                                 Defaults to `#{DEFAULT_USER_COUNT}'

      --db-start-id number       The ID to assign to the first created DB.
                                 Subsequent DBs will have an ID which is an
                                 increment of this initial ID.
                                 Defaults to `#{DEFAULT_DB_START_ID}'

      --db-prefix string         A string prefix to prepend to each DB name.
                                 Defaults to `#{DEFAULT_DB_PREFIX}'

      --doc-start-id number      The ID to assign to the first created doc for
                                 each created DB.
                                 Subsequent docs will have an ID which is an
                                 increment of this initial ID.
                                 Defaults to `#{DEFAULT_DOC_START_ID}'

      --doc-prefix string        A string prefix to prepend to each doc name.
                                 Defaults to `#{DEFAULT_DOC_PREFIX}'

      --user-start-id number     The ID to assign to the first created user.
                                 Subsequent users will have an ID which is an
                                 increment of this initial ID.
                                 Defaults to `#{DEFAULT_USER_START_ID}'

      --user-prefix string       A string prefix to prepend to each user name.
                                 Defaults to `#{DEFAULT_USER_PREFIX}'

      --doc-tpl file             The template to use for each doc.
                                 Defaults to `#{DEFAULT_DOC_TPL}'

      --sec-obj file             A file containing the JSON security object
                                 to add to each created DB.
                                 Defaults to none.

      --recreate-dbs             If a DB already exists, it is deleted and created.

_EOH_

        exit 0
    end


    class Settings
        include Singleton

        attr_accessor :debug
        attr_accessor :host
        attr_accessor :port
        attr_accessor :dbs
        attr_accessor :docs
        attr_accessor :users
        attr_accessor :db_start_id
        attr_accessor :doc_start_id
        attr_accessor :user_start_id
        attr_accessor :db_prefix
        attr_accessor :doc_prefix
        attr_accessor :user_prefix
        attr_accessor :doc_tpl
        attr_accessor :sec_obj
        attr_accessor :recreate_dbs
    end


    class Streamer
        def initialize(filename)
            @f = File.open filename
            @sz = File.size filename
        end

        def size
            @sz
        end

        def read(len)
            @f.read len
        end
    end


    def self.create_dbs
        1.upto($settings.dbs) do |i|
            db_name = "#{$settings.db_prefix}#{$settings.db_start_id + i - 1}"

            if $settings.recreate_dbs
                r = from_json(delete("/#{db_name}").body)
                log_info("Deleted DB named `#{db_name}'") if r["ok"]
            end

            r = from_json(put("/#{db_name}").body)
            if not r["ok"]
                if r["error"] == "file_exists"
                    log_info "DB `#{db_name}' already exists"
                else
                    log_error("Error creating DB `#{db_name}'", r)
                    next
                end
            else
                log_info "Created DB named `#{db_name}'"
            end

            create_docs db_name

            if not $settings.sec_obj.nil?
                r = from_json(put("/#{db_name}/_security", $settings.sec_obj).body)
                if not r["ok"]
                    log_error("Error setting the security object for DB `#{db_name}'", r)
                else
                    log_info "Updated the security object for DB `#{db_name}'"
                end
            end
        end

        create_users
    end


    def self.create_docs(db_name)
        1.upto($settings.docs) do |i|
            doc_name = "#{$settings.doc_prefix}#{$settings.doc_start_id + i - 1}"
            uri = "/#{db_name}/#{doc_name}"
            doc = get_doc_tpl($settings.doc_start_id + i - 1)
            atts = parse_doc_atts doc
            doc.delete "_attachments"
            req = put(uri, doc)
            r = from_json req.body
            if not r["ok"]
                log_error("Error creating doc at #{uri}", r)
            else
                log_info "Created doc at #{uri}"
                upload_doc_atts(db_name, doc, r["rev"], atts)
            end
        end
    end


    def self.upload_doc_atts(db_name, doc, doc_rev, atts)
        doc_id = doc["_id"]
        doc_path = "/#{db_name}/#{doc_id}"

        atts.each do |att|
            name = att["name"]
            type = att["content_type"]
            att_path = "#{doc_path}/#{name}"
            res = nil

            if att.has_key? "data"
                res = put(att_path, att["data"], type, {"rev" => doc_rev})
            else
                stream = Streamer.new(att["file"]) rescue nil
                if stream.nil?
                    log_error "Couldn't open attachment file #{att['file']}"
                    next
                end

                res = put_stream(att_path, stream, type, {"rev" => doc_rev})
            end

            r = from_json res.body
            if not res.kind_of?(Net::HTTPCreated)
                log_error("Error uploading attachment at #{att_path}", r)
                next
            end

            log_info "Uploaded attachment #{att_path}"
            doc_rev = r["rev"]
        end
    end


    def self.create_users
        # TODO
    end


    def self.get_doc_tpl(doc_id_counter)
        tpl = $settings.doc_tpl.dup

        tpl.gsub!(/([^\\]|^)#\{doc_id_counter\}/, "\\1#{doc_id_counter}")
        tpl.gsub!(/([^\\]|^)#\{db_prefix\}/, "\\1#{$settings.db_prefix}")
        tpl.gsub!(/([^\\]|^)#\{doc_prefix\}/, "\\1#{$settings.doc_prefix}")
        tpl.gsub!(/([^\\]|^)#\{user_prefix\}/, "\\1#{$settings.user_prefix}")

        tpl = doc_tpl_gen_random_ints tpl
        tpl = doc_tpl_gen_random_strings tpl

        tpl.gsub!(/\\#/, '#')

        doc_tpl = from_json tpl
        check_conditionals doc_tpl
    end


    def self.check_conditionals(doc_tpl)
        del_keys = []
        rename_keys = []
        doc_tpl.each_key do |k|
            if k =~ /^\s*#\{if\((.*)\)\}/
                expr = $1
                if not eval(expr)
                    del_keys.push k
                else
                    rename_keys.push k
                end
            end

            if doc_tpl[k].is_a? Hash
                check_conditionals doc_tpl[k]
            end
        end

        del_keys.each do |k|
            doc_tpl.delete k
        end
        rename_keys.each do |k|
            new_k = k.gsub(/^\s*#\{if\((.*)\)\}/, '')
            doc_tpl[new_k] = doc_tpl[k]
            doc_tpl.delete k
        end

        doc_tpl
    end


    def self.doc_tpl_gen_random_ints(tpl)
        tpl.gsub!(/([^\\]|^)#\{random_int\(\s*(\d+)\s*,\s*(\d+)\s*\)\}/) do |match|
            min = $2
            max = $3
            value = rand($3) + 1 + Integer($2)
            $1 + value.to_s
        end
        tpl
    end


    def self.doc_tpl_gen_random_strings(tpl)
        tpl.gsub!(/([^\\]|^)#\{random_string\}/) do |match|
            length = rand(990) + 10
            str = gen_string length
            $1 + str
        end
        tpl.gsub!(/([^\\]|^)#\{random_string\(\s*(\d+)\s*\)\}/) do |match|
            length = Integer $2
            str = gen_string length
            $1 + str
        end
        tpl
    end


    def self.gen_string(length)
        chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        result = ''

        1.upto(length) do |i|
            j = rand(chars.length)
            result += chars[j, 1]
        end

        result
    end


    def self.put(path, data = '', content_type = "application/json", query = {}, escape = true)
        url = path + hash_to_query_string(query)
        url = URI.escape(url) if escape
        req = Net::HTTP::Put.new(url)
        req["content-type"] = content_type
        req.body = to_json(data)
        request req
    end


    def self.put_stream(path, streamer, content_type = nil, query = {}, escape = true)
        url = path + hash_to_query_string(query)
        url = URI.escape(url) if escape
        req = Net::HTTP::Put.new(url)
        req["content-type"] = content_type if not content_type.nil?
        req["transfer-encoding"] = "chunked"
        #req.content_length = streamer.size
        req.body_stream = streamer
        Net::HTTP.new($settings.host, $settings.port).start do |http|
            http.request req
        end
    end


    def self.get(path, query = {}, escape = true)
        url = path + hash_to_query_string(query)
        url = URI.escape(url) if escape
        request Net::HTTP::Get.new(url)
    end


    def self.delete(path, escape = true)
        url = path
        url = URI.escape(url) if escape
        request Net::HTTP::Delete.new(url)
    end


    def self.request(req)
        res = Net::HTTP.start($settings.host, $settings.port) do |http|
            http.request(req)
        end
        # if (not res.kind_of?(Net::HTTPSuccess))
        #     handle_error(req, res)
        # end
        log_debug "Response has content-type: `#{res['content-type']}'"
        res
    end


    def self.from_json(body)
        begin
            JSON.parse("[" + body + "]")[0]
        rescue
            log_error "Invalid JSON string:\n\n#{body}"
            exit 1
        end
    end


    def self.to_json(json_obj)
        JSON.pretty_generate json_obj
    end


    def self.hash_to_query_string(query)
        str = ""
        query.each_pair do |key, value|
            str += key + "=" + value + "&"
        end
        str = "?" + str if not str.empty?
        str = str.chop if str.end_with? "&"
        str
    end


    def self.debug_req_res(req, res, show_body = true)
        if $settings.debug
            log_debug(
                "HTTP request/response\n" +
                "Response code: #{res.code} (#{res.message})\n" +
                "Request method: #{req.method}\n" +
                "Request target URI: #{req.path}" +
                (show_body ? "\nResponse body:\n\n#{res.body}" : "")
            )
        end
    end


    def self.handle_error(req, res)
        log_error("HTTP request error:\n" +
            "#{res.code}: #{res.message}\nMETHOD: #{req.method}\nURI: #{req.path}\nBODY: #{res.body}")
        exit 1
    end


    def self.parse_command_line
        if ARGV.include? '--help' or ARGV.include? '-h'
          showhelp
        end

        $settings = Settings.instance
        $settings.debug = DEFAULT_DEBUG
        $settings.host = DEFAULT_HOST
        $settings.port = DEFAULT_PORT
        $settings.dbs = DEFAULT_DB_COUNT
        $settings.docs = DEFAULT_DOC_COUNT
        $settings.users = DEFAULT_USER_COUNT
        $settings.db_start_id = DEFAULT_DB_START_ID
        $settings.doc_start_id = DEFAULT_DOC_START_ID
        $settings.user_start_id = DEFAULT_USER_START_ID
        $settings.db_prefix = DEFAULT_DB_PREFIX
        $settings.doc_prefix = DEFAULT_DOC_PREFIX
        $settings.user_prefix = DEFAULT_USER_PREFIX
        $settings.doc_tpl = DEFAULT_DOC_TPL
        $settings.sec_obj = DEFAULT_SEC_OBJ
        $settings.recreate_dbs = DEFAULT_RECREATE_DBS

        opts = GetoptLong.new(
            ['--debug', GetoptLong::NO_ARGUMENT],
            ['--host', GetoptLong::REQUIRED_ARGUMENT],
            ['--port', GetoptLong::REQUIRED_ARGUMENT],
            ['--dbs', GetoptLong::REQUIRED_ARGUMENT],
            ['--docs', GetoptLong::REQUIRED_ARGUMENT],
            ['--users', GetoptLong::REQUIRED_ARGUMENT],
            ['--db-start-id', GetoptLong::REQUIRED_ARGUMENT],
            ['--doc-start-id', GetoptLong::REQUIRED_ARGUMENT],
            ['--user-start-id', GetoptLong::REQUIRED_ARGUMENT],
            ['--db-prefix', GetoptLong::REQUIRED_ARGUMENT],
            ['--doc-prefix', GetoptLong::REQUIRED_ARGUMENT],
            ['--user-prefix', GetoptLong::REQUIRED_ARGUMENT],
            ['--doc-tpl', GetoptLong::REQUIRED_ARGUMENT],
            ['--sec-obj', GetoptLong::REQUIRED_ARGUMENT],
            ['--recreate-dbs', GetoptLong::NO_ARGUMENT]
        )
        opts.quiet = true

        begin
            opts.each do |opt, arg|
                case opt
                    when '--debug'
                        $settings.debug = true
                    when '--host'
                        $settings.host = arg
                    when '--port'
                        $settings.port = arg
                    when '--dbs'
                        $settings.dbs = Integer(arg) rescue DEFAULT_DB_COUNT
                    when '--docs'
                        $settings.docs = Integer(arg) rescue DEFAULT_DOC_COUNT
                    when '--users'
                        $settings.users = Integer(arg) rescue DEFAULT_USER_COUNT
                    when '--db-start-id'
                        $settings.db_start_id = Integer(arg) rescue DEFAULT_DB_START_ID
                    when '--doc-start-id'
                        $settings.doc_start_id = Integer(arg) rescue DEFAULT_DOC_START_ID
                    when '--user-start-id'
                        $settings.user_start_id = Integer(arg) rescue DEFAULT_USER_START_ID
                    when '--db-prefix'
                        $settings.db_prefix = arg
                    when '--doc-prefix'
                        $settings.doc_prefix = arg
                    when '--user-prefix'
                        $settings.user_prefix = arg
                    when '--doc-tpl'
                        $settings.doc_tpl = arg
                    when '--sec-obj'
                        $settings.sec_obj = arg
                    when '--recreate-dbs'
                        $settings.recreate_dbs = true
                end
            end
        rescue GetoptLong::Error
            log_error "#{opts.error_message}"
            exit 1
        end

        parse_doc_tpl $settings.doc_tpl
        parse_sec_obj($settings.sec_obj) unless $settings.sec_obj.nil?
    end


    def self.parse_doc_tpl(tpl_file)
        f = File.open(tpl_file) rescue nil

        if f.nil?
            log_error "Couldn't open the doc template file `#{tpl_file}'"
            exit 1
        end

        tpl = ''
        f.each_line do |line|
            next if line =~ /^\s*#/
            next if line =~ /^\s*$/
            tpl += line
        end

        f.close
        $settings.doc_tpl = tpl
    end


    def self.parse_doc_atts(doc_tpl_hash)
        result = []

        if doc_tpl_hash.has_key?("_attachments")
            atts = doc_tpl_hash["_attachments"]

            if not atts.is_a? Hash
                log_error "The _attachments attribute of the doc template must be an hash"
                exit 1
            end

            atts.each_pair do |att_name, att_details|
                if not att_details.is_a? Hash
                    log_error "The _attachments/#{att_name} attribute of the doc template must be an hash"
                    exit 1
                end

                att_entry = {}
                att_entry["name"] = att_name
                if att_details.has_key?("content_type")
                    att_entry["content_type"] = att_details["content_type"]
                end
                if att_details.has_key?("data")
                    if att_details["data"] =~ /^\s*(?:[^\\]|^)#\{file\((.*?)\)\}\s*$/
                        att_entry["file"] = $1
                    else
                        att_entry["data"] = att_details["data"]
                    end
                else
                    log_error "Missing data attribute for the attachment named `#{att_name}'"
                    exit 1
                end

                result.push att_entry
            end
        end

        result
    end


    def self.parse_sec_obj(sec_obj_file)
        f = File.open(sec_obj_file) rescue nil

        if f.nil?
            log_error "Couldn't open the security object file `#{sec_obj_file}'"
            exit 1
        end

        $settings.sec_obj = from_json(f.read)
        f.close
        $settings.sec_obj
    end


    def self.log_error(msg, json_obj = nil)
        msg0 = "[ERROR] #{msg}"
        if not json_obj.nil?
            msg0 += ":\n" + to_json(json_obj)
        end
        STDERR.puts(msg0 + "\n")
    end


    def self.log_warn(msg)
        STDERR.puts "[WARN] #{msg}\n"
    end


    def self.log_info(msg)
        STDOUT.puts "[INFO] #{msg}\n"
    end


    def self.log_debug(msg)
        if $settings.debug
            STDERR.puts "[DEBUG] #{msg}\n"
        end
    end


    def self.run
        parse_command_line
        create_dbs
        create_users
    end


end # end of module SeatOnCouch


SeatOnCouch.run
