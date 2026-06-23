import Config

# This is a library: do not set Application env that would override consuming apps.
# Keep this file limited to tooling configuration.

import_config "#{config_env()}.exs"
