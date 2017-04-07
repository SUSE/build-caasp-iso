#!/usr/bin/env ruby
# Copyright (C) 2017 SUSE LLC
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "open3"
require "nokogiri"

def log(message, command: false)
  if command
    printf "> #{message}..."
    STDOUT.flush
  else
    puts "> #{message}"
  end
end

def exec_command(command, description = nil, stdin = nil)
  log description, command: true unless description.nil?
  stdout, stderr, status = Open3.capture3 command, stdin_data: stdin
  unless description.nil?
    if status.exitstatus.zero?
      puts " success"
    else
      puts " failed (retcode: #{status})"
    end
  end
  return stdout, stderr, status
end

class BuildScript
  def self.request_sudo
    log "Requesting sudo"
    exec_command "sudo -v"
  end

  def self.project_dir
    File.expand_path File.dirname(__FILE__)
  end

  def self.cached_file_path(file)
    File.join project_dir, ".cache", file
  end

  def self.cached_file(file)
    Dir.mkdir File.join(project_dir, ".cache") rescue nil
    begin
      File.read cached_file_path(file)
    rescue Errno::ENOENT
      contents = yield
      File.open(cached_file_path(file), "w") do |file|
        file.write contents
      end
      contents
    end
  end
end

class BuildService
  def self.iso_project_dir
    File.join BuildScript.project_dir,
              "Devel:CASP:1.0:ControllerNode",
              "_product:CAASP-dvd5-DVD-x86_64"
  end

  def self.kiwi_filename
    "CAASP-dvd5-DVD-x86_64.kiwi"
  end

  def self.kiwi_file_path
    File.join BuildService.iso_project_dir, kiwi_filename
  end

  def self.generated_kiwi_filename
    "CAASP-dvd5-DVD-x86_64.generated.kiwi"
  end

  def self.generated_kiwi_file_path
    File.join BuildService.iso_project_dir, generated_kiwi_filename
  end

  def self.checkout
    Dir.chdir(BuildScript.project_dir) do
      unless Dir.exists? "Devel:CASP:1.0:ControllerNode"
        exec_command "osc co Devel:CASP:1.0:ControllerNode",
                     "Checking out Devel:CASP:1.0:ControllerNode"
      end
    end
  end

  def self.chroot_dir
    "/var/tmp/build-root/images-x86_64"
  end

  def self.exec_command_chroot(command, description = nil)
    build_images unless Dir.exists? chroot_dir
    exec_command "osc chroot --root=#{chroot_dir}",
                 description.nil? ? nil : "(chroot) #{description}", command
  end

  def self.buildinfo
    BuildScript.cached_file("_product:CAASP-dvd5-DVD-x86_64.buildinfo") do
      stdout, status = nil, nil
      Dir.chdir(iso_project_dir) do
        stdout, _, status = exec_command "osc buildinfo images #{kiwi_filename}",
                                         "Retrieving buildinfo"
      end
      raise "buildinfo could not be retrieved" unless status.exitstatus.zero?
      stdout
    end
  end

  def self.patch_kiwi
    doc = Nokogiri::XML File.read(kiwi_file_path)
    buildinfo_doc = Nokogiri::XML buildinfo
    log "Patching kiwi definition"
    doc.search("//instrepo").remove
    all_paths = buildinfo_doc.xpath("//path").map do |path|
      ["obs://#{path["project"]}", path["repository"]]
    end.uniq
    all_paths.each_with_index do |path_info, i|
      instrepo = Nokogiri::XML::Builder.with(doc.at_css("instsource")) do |doc|
        doc.instrepo(name: "obsrepository_#{i + 1}", priority: i + 1, local: true) do |instrepo|
          instrepo.source path: File.join(path_info)
        end
      end
    end
    File.open(generated_kiwi_file_path, "w") { |file| file.write doc.to_s }
  end

  def self.generate_private_key
    _, _, status = exec_command_chroot "grep ^default-key .gnupg/gpg.conf",
                                       "Checking if a default-key exists in GPG configuration"
    return if status.exitstatus.zero?
    key_generation = """Key-Type: DSA
                        Key-Length: 1024
                        Subkey-Type: ELG-E
                        Subkey-Length: 1024
                        Name-Real: ACME ISO Generation
                        Name-Email: acme-iso-generation@example.com
                        Expire-Date: 0
                        %commit"""
    _, stderr, status = exec_command_chroot "echo '#{key_generation}' | gpg --gen-key --batch",
                                            "Generating GPG keypair"
    if status.exitstatus.zero?
      stderr =~ /key ([^\s]+)/
      key = $1
      exec_command_chroot "echo 'default-key #{key}' >> .gnupg/gpg.conf",
                          "Setting generated key #{key} as the default signing key"
    else
      raise 'error when creating GPG keypair'
    end
  end

  def self.build_images
    Dir.chdir(iso_project_dir) do
      exec_command "osc build --trust-all-projects images #{generated_kiwi_filename}",
                   "Building images"
    end
  end
end

class CaaSP
  def self.iso_path
    "/var/tmp/build-root/images-x86_64/usr/src/packages/KIWI/SUSE-CaaS-Platform-1.0-DVD-x86_641.iso"
  end

  def self.build_iso
    BuildScript.request_sudo
    BuildService.checkout
    BuildService.patch_kiwi
    BuildService.generate_private_key
    BuildService.build_images
    if File.exists? iso_path
      log "Please, find your ISO located at #{iso_path}"
    else
      log "ISO image couldn't be found at #{iso_path}. Something went wrong, sorry..."
    end
  end
end

CaaSP.build_iso
