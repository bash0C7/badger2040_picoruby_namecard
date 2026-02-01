PICORUBY_BIN = "/Users/bash/src/Arduino/picoruby-recipes/components/R2P2-ESP32/components/picoruby-esp32/picoruby/bin/picorbc"
DEVICE_PATH = "/Volumes/NO NAME/home/"

task default: [:deploy, :monitor]

desc "Compile all .rb files in project root"
task :compile do
  rb_files = Dir.glob("*.rb")
  if rb_files.empty?
    puts "❌ No .rb files found in project root"
    exit 1
  end

  puts "Compiling #{rb_files.length} file(s)..."
  rb_files.each do |rb_file|
    mrb_file = rb_file.gsub(/\.rb$/, ".mrb")
    puts "  Compiling #{rb_file} → #{mrb_file}..."
    sh "#{PICORUBY_BIN} #{rb_file}"
  end
  puts "✓ Compilation complete!"
end

desc "Compile and deploy to Badger 2040"
task deploy: :compile do
  mrb_files = Dir.glob("*.mrb")
  if mrb_files.empty?
    puts "❌ No .mrb files found after compilation"
    exit 1
  end

  puts "Deploying #{mrb_files.length} file(s) to Badger 2040..."
  mrb_files.each do |mrb_file|
    puts "  Copying #{mrb_file}..."
    sh "cp '#{mrb_file}' '#{DEVICE_PATH}'"
  end
  puts "✓ Deployment complete!"
end

desc "Monitor serial output via screen"
task :monitor do
  port = `ls -1 /dev/tty.usb* 2>/dev/null | head -1`.strip
  if port.empty?
    puts "❌ No USB serial port found"
    exit 1
  end
  puts "Connecting to #{port}..."
  sh "screen #{port} 115200"
end

desc "Clean compiled files"
task :clean do
  mrb_files = Dir.glob("*.mrb")
  if mrb_files.empty?
    puts "ℹ No .mrb files to clean"
  else
    puts "Removing #{mrb_files.length} compiled file(s)..."
    rm_f mrb_files
    puts "✓ Cleaned"
  end
end
