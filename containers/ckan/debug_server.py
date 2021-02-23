# -*- coding: utf-8 -*-

import os
from ckan.config.middleware import make_app
from ckan.cli import CKANConfigLoader
from logging.config import fileConfig as loggingFileConfig
from werkzeug.serving import run_simple

config_filepath='/etc/ckan/docker.ini'
config = CKANConfigLoader(config_filepath).get_config()
application = make_app(config)
run_simple(
    '0.0.0.0',
    5000,
    application,
    use_reloader=False,
    use_evalex=True,
    threaded=False,
    processes=1,
)