require "mikrotik-backup/version"
require 'net/ssh'
require 'net/sftp'
# MikroTik backup class
# noinspection RubyArgCount
class MTik_backup
  # Initialize
  def initialize(config)
    @config = config
    logger
  end
  # Setting for Ruby Logger
  def logger(log_level = Logger::ERROR,log_file = nil)
    if log_file.nil?
      @log = Logger.new(STDOUT)
    else
      @log = Logger.new(log_file)
    end
    @log.level = log_level
    @log.formatter = proc { |severity, datetime, progname, msg|
      "[#{datetime.strftime("%Y-%m-%d %H:%M:%S")}] #{severity}: #{msg}\n"
    }
  end
  # Backup MTik config
  def backup
    @config.each do |config|
      connect_to_host(config[:host],config[:user],config[:password])
      backup_config(config[:name],config[:format])
    end
    return true
  end
  # Only download MTik config
  def download
    @config.each do |config|
      download_backup(config[:host],config[:user],config[:password],config[:name],config[:path],config[:format])
    end
    return true
  end
  # Backup and download MTik config
  def backup_and_download
    @config.each do |config|
      connect_to_host(config[:host],config[:user],config[:password])
      backup_config(config[:name],config[:format])
      download_backup(config[:host],config[:user],config[:password],config[:name],config[:path],config[:format])
    end
    return true
  end

# Private section
  private
  # Function connect to SSH/SFTP host
  def connect_to_host(host,user,password,sftp=false)
    begin
      if sftp
        @log.info("SFTP connect to host #{host}")
        @ssh_connect = Net::SFTP.start(host,user,:password=>password)
      else
        @log.info("SSH connect to host #{host}")
        @ssh_connect = Net::SSH.start(host,user,:password=>password)
      end
    rescue Exception => error
      @log.error("#{error}")
      exit
    end
  end
  # Backup function, send SSH command
  def backup_config(name,format='binary')
    @log.info("Backup MikroTik configuration")
    if format == 'binary'
      send_command("/system backup save name=#{name}")
    elsif format == 'script'
      send_command("/export file=#{name}")
    end
    @ssh_connect.close
  end
  # Download backup file from host
  def download_backup(host,user,password,name,path,format)
    connect_to_host(host,user,password,true)
    if format == 'binary'
      local_file = path+name+".backup"
      remote_file = name+".backup"
    elsif format== 'script'
      local_file = path+name+".rsc"
      remote_file = name+".rsc"
    end
    download_file(remote_file,local_file)
    @ssh_connect.close(@ssh_connect)
  end
  # Send command to host (SSH)
  def send_command(command)
    begin
      @ssh_connect.exec!(command)
    rescue Exception => error
      @log.error("#{error}")
    end
  end
  # Download file from host
  def download_file(remote_file, local_file)
    begin
      @log.info("Download file #{remote_file} to #{local_file}")
      @ssh_connect.download!(remote_file,local_file)
    rescue Exception => error
      @log.error("#{error}")
      exit
    end
  end
end

