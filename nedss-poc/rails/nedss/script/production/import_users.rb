require 'yaml'

def get_setup_data
  config = YAML::load_file "./config.yml"
    
  @postgres_dir = config['postgres_dir']
  @host = config['host']
  @port = config['port']
  @username = config['priv_uname']
  @password = config['priv_passwd']
  @database = config['database']
  @nedss_user = config['nedss_uname']
  @nedss_user_pwd = config['nedss_user_passwd']

  @psql = @postgres_dir + "/psql"
  ENV["PGPASSWORD"] = @password
  
end

def setup_data_is_correct 
  puts 
  puts "The following information has been collected"
  puts 
  puts "PostgreSQL client location = #{@postgres_dir}"
  puts "PostgreSQL host server = #{@host}"
  puts "PostgreSQL TCP listen port = #{@port}"
  puts "Database name = #{@database}"
  puts "Database privileged username = #{@username}"
  puts "Privileged user's password = #{@password}"
  puts "NEDSS username = #{@nedss_user}"
  puts "NEDSS user's password = #{@nedss_user_pwd}"

  puts
  repeat = get_input_from_user("Is the above information correct (y/n)?", "y")
  repeat.downcase == "y" ? false : true
end

def get_input_from_user(prompt, default)
  the_prompt = prompt += " [#{default}] "
  while true
    print prompt
    value = gets.chomp
    value = default if value == ""
    if value == "" # No default supplied
      puts "==> Value may not be blank"
      redo
    end
    return value
  end
end

def import_users 
  puts "deleting contents of user tables."
  
  dump_dir = "./db-dump"
    
  system("#{@psql} -U #{@username} -h #{@host} -p #{@port} #{@database} -e -f delete_users.sql")
  
  puts "importing users tables."
  puts "#{@psql} -U #{@username} -h #{@host} -p #{@port} #{@database} -e -f #{dump_dir}/priv.sql"
  system("#{@psql} -U #{@username} -h #{@host} -p #{@port} #{@database} -e -f #{dump_dir}/priv.sql")
  system("#{@psql} -U #{@username} -h #{@host} -p #{@port} #{@database} -e -f #{dump_dir}/roles.sql")
  system("#{@psql} -U #{@username} -h #{@host} -p #{@port} #{@database} -e -f #{dump_dir}/users.sql")
  system("#{@psql} -U #{@username} -h #{@host} -p #{@port} #{@database} -e -f #{dump_dir}/entitlements.sql")
  system("#{@psql} -U #{@username} -h #{@host} -p #{@port} #{@database} -e -f #{dump_dir}/privileges_roles.sql")
  system("#{@psql} -U #{@username} -h #{@host} -p #{@port} #{@database} -e -f #{dump_dir}/role_memberships.sql")
end

puts ""
puts "* This script will export users from NEDSS. It has been tested with R1 and R2."
puts ""
server_machine = get_input_from_user "Are you ready to proceed (y/n)?", "y"
exit if server_machine.downcase == "n"

while true
  get_setup_data
  if setup_data_is_correct
    puts "\n==> Repeating\n\n"
    redo
  end
  break
end

exit unless import_users
