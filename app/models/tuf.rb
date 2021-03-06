require 'json'
require 'fileutils'

class Tuf
  def self.generate_metadata(target_files)
    FileUtils.mkdir_p("server/metadata") # TODO: Abstract this

    targets = {
      signatures: [],
      version: 2,
      signed: {
        _type: "Targets",
        expires: Time.now + 10000, # TODO: There is a recommend value in pec
        targets: {},
      },
    }

    # TODO: Get existing and append, rather than overwrite
    target_files.each do |file, hash, length|
      targets[:signed][:targets][file] = {
        hashes: {
          sha256: hash
        },
        length: length
      }
    end

    # TODO: Actually sign with something
    targets_sig = Digest::MD5.hexdigest(targets[:signed].to_json)

    targets[:signatures] = [{
      keyid:  'abc123',
      method: 'md5lol',
      sig:    targets_sig,
    }]
    require 'pp'

    # TODO: where should this live?
    File.write('server/metadata/targets.txt', targets.to_json)

    # create root.txt
    roles = [:release, :root, :targets, :timestamp]

    root = {
      signed: {
        _type: "Root",
        expires: Time.now + 10000, # TODO: There is a recommend value in pec
        keys: {
          abc123: {
            keytype: "md5lol",
            keyval: {
              private: "",
              public: "asdfasdfsadfsadlkfjsad",
            }
          }
        },
        roles: roles.each_with_object({}) do |role, hash|
          hash[role] = {
            keyids: ["abc123"],
            threshold: 1,
          }
        end
      }
    }

    root_sig = Digest::MD5.hexdigest(root[:signed].to_json)

    root[:signatures] = [{
      keyid:  'abc123',
      method: 'md5lol',
      sig:    root_sig,
    }]
    File.write('server/metadata/root.txt', root.to_json)

    release = {
      signatures: [],
      version: 2,
      signed: {
        _type: "Release",
        expires: Time.now + 10000, # TODO: There is a recommend value in pec
        meta: {},
      },
    }

    Dir.chdir("server/metadata") do
      %w(root.txt targets.txt).each do |file|
        hash = Digest::SHA2.file(file).hexdigest
        release[:signed][:meta][file] = {
          hashes: {
            sha256: hash
          },
          length: File.size(file)
        }
      end
    end

    # TODO: Actually sign with something
    release_sig = Digest::MD5.hexdigest(release[:signed].to_json)

    release[:signatures] = [{
      keyid:  'abc123',
      method: 'md5lol',
      sig:    release_sig,
    }]

    File.write('server/metadata/release.txt', release.to_json)
    require 'pp'

    timestamp = {
      signatures: [],
      version: 2,
      signed: {
        _type: "Timestamp",
        expires: Time.now + 10000, # TODO: There is a recommend value in pec
        meta: {},
      },
    }

    Dir.chdir("server/metadata") do
      %w(release.txt).each do |file|
        hash = Digest::SHA2.file(file).hexdigest
        timestamp[:signed][:meta][file] = {
          hashes: {
            sha256: hash
          },
          length: File.size(file)
        }
      end
    end

    FileUtils.mv(
      "server/metadata/release.txt",
      "server/metadata/release." + timestamp[:signed][:meta]['release.txt'][:hashes][:sha256] + ".txt"
    )

    FileUtils.mv(
      "server/metadata/root.txt",
      "server/metadata/root." + release[:signed][:meta]['root.txt'][:hashes][:sha256] + ".txt"
    )

    FileUtils.mv(
      "server/metadata/targets.txt",
      "server/metadata/targets." + release[:signed][:meta]['targets.txt'][:hashes][:sha256] + ".txt"
    )

    timestamp_sig = Digest::MD5.hexdigest(timestamp[:signed].to_json)

    timestamp[:signatures] = [{
      keyid:  'abc123',
      method: 'md5lol',
      sig:    timestamp_sig,
    }]
    File.write('server/metadata/timestamp.txt', timestamp.to_json)
  end
end
