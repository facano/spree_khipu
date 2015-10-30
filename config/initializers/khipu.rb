module KhipuConfig
  CONFIG = YAML.load_file(Rails.root.join("config/khipu.yml"))[Rails.env] rescue nil
  PROTOCOL = CONFIG ? CONFIG['protocol'] : nil
end