import os
import sys
import argparse
import heroku3
from time import time
from time import sleep
import logging

logging.basicConfig(
    stream=sys.stdout,
    level=logging.DEBUG,
    format='%(thread)d: %(message)s'  #tried process but it was always "6" on heroku
)
logger = logging.getLogger("heroku_utils")

def num_dynos(process_name, app_name):
    heroku_conn = heroku3.from_key(os.getenv("HEROKU_API_KEY"))
    num_dynos = 0
    try:
        dynos = heroku_conn.apps()[app_name].dynos()[process_name]
        num_dynos = len(dynos)
    except (KeyError, TypeError) as e:
        pass
    return num_dynos

def scale_dyno(n, process_name, app_name):
    logger.info(u"starting with {} dynos".format(num_dynos(process_name)))
    logger.info(u"setting to {} dynos".format(n))
    heroku_conn = heroku3.from_key(os.getenv("HEROKU_API_KEY"))
    app = heroku_conn.apps()[app_name]
    app.process_formation()[process_name].scale(n)

    logger.info(u"sleeping for 2 seconds while it kicks in")
    sleep(2)
    logger.info(u"verifying: now at {} dynos".format(num_dynos(process_name)))
