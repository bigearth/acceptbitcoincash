require 'yaml'
require 'kwalify'
require 'diffy'
require 'safe_yaml/load'
@output = 0
@warning = 0
@total_tracked = 0

# Send error message
def error(msg)
  @output += 1
  puts "  #{@output}. #{msg}"
end

# rubocop:disable AbcSize
def process_section(section, validator)
  section_file = "_data/#{section['id']}.yml"
  data = SafeYAML.load_file(File.join(__dir__, section_file))
  calls = data['rpc']
  validate_data(validator, data, section_file, 'name', calls)

  # Check section alphabetization
  validate_alphabetical(calls, 'name', section_file)

  calls.each do
    @total_tracked += 1
  end
end

def validate_data(validator, data, file, identifier, subset = nil)
  val = 2
  if subset.nil?
    subset = data if subset.nil?
    val -= 1
  end

  validator.validate(data).each do |e|
    msg = parse_error_msg(e, val, subset)
    error("#{file}:#{subset.at(e.path.split('/')[val].to_i)[identifier]}"\
          ": #{e.message}#{msg}")
  end
end

def parse_error_msg(error, val, subset)
  msg = ''
  if error.message.include? " is already used at '/"
    err_split = error.message.split('already used at')[1].split('/')
    return "\nThese listings share the same "\
          "'#{err_split[val + 1].split('\'')[0]}':"\
          "\n#{subset.at(err_split[val].to_i).to_yaml}"\
          "#{subset.at(error.path.split('/')[val].to_i).to_yaml}\n"
  end

  msg
end
# rubocop:enable AbcSize

def validate_schema(parser, schema)
  parser.parse_file(File.join(__dir__, schema))
  errors = parser.errors()
  return unless errors && !errors.empty?
  errors.each do |e|
    error(e.message.to_s)
  end
end

def validate_alphabetical(set, identifier, set_name)
  return unless set != (sorted = set.sort_by { |s| s[identifier].downcase })
  msg = Diffy::Diff.new(set.to_yaml, sorted.to_yaml, context: 10).to_s(:color)
  error("#{set_name} not ordered by #{identifier}. Correct order:#{msg}")
end

def get_validator(schema_name)
  schema = SafeYAML.load_file(File.join(__dir__, schema_name))
  Kwalify::Validator.new(schema)
end

# Load each section, check for errors such as invalid syntax
# as well as if an image is missing
begin
  # meta validator
  metavalidator = Kwalify::MetaValidator.instance

  # validate schema definition
  parser = Kwalify::Yaml::Parser.new(metavalidator)
  Dir['*_schema.yml'].each do |schema|
    validate_schema(parser, schema)
  end

  validator = get_validator('sections_schema.yml')

  file_name = '_data/sections.yml'
  sections = SafeYAML.load_file(file_name)
  validate_data(validator, sections, file_name, 'id')
  validate_alphabetical(sections, 'id', file_name)

  validator = get_validator('rpc_schema.yml')

  sections.each do |section|
    process_section(section, validator)
  end

  puts "<--------- Total calls listed: #{@total_tracked} --------->\n"

  @output -= @warning

  exit 1 if @output > 0
rescue Psych::SyntaxError => e
  puts "<--------- ERROR in a YAML file --------->\n"
  puts e
  exit 1
rescue StandardError => e
  puts e
  exit 1
else
  if @warning > 0
    puts "<--------- No errors found! --------->\n"
    puts "<--------- #{@warning} warning(s) reported! --------->\n"
  else
    puts "<--------- No errors. You\'re good to go! --------->\n"
  end
end
