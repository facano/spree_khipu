module KhipuConfig
  CONFIG = YAML.load_file(Rails.root.join("config/khipu.yml"))[Rails.env] rescue nil
  PROTOCOL = CONFIG ? CONFIG['protocol'] : nil
  DOMAIN_URL = CONFIG ? CONFIG['domain_url'] : nil
end