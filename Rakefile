PICORUBY_BIN = "/Users/bash/src/Arduino/picoruby-recipes/components/R2P2-ESP32/components/picoruby-esp32/picoruby/bin/picorbc"
DEVICE_PATH = "/Volumes/NO NAME/home/"

task default: :deploy

desc "Compile app.rb to app.mrb"
task :compile do
  puts "Compiling app.rb..."
  sh "#{PICORUBY_BIN} app.rb"
  puts "✓ Compiled app.mrb"
end

desc "Compile and deploy to Badger 2040"
task deploy: :compile do
  puts "Deploying to Badger 2040..."
  sh "cp app.mrb '#{DEVICE_PATH}'"
  puts "✓ Deployment complete!"
end

desc "Clean compiled files"
task :clean do
  rm_f "app.mrb"
  puts "✓ Cleaned"
end
