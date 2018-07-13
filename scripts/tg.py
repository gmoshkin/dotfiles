#!/usr/bin/env python3.7
# -*- coding: utf-8 -*-

import configparser
from os.path import expanduser
import telethon
import time
import argparse

def parse_args():
    arg_parser = argparse.ArgumentParser(
        'Show unread messages count'
    )
    arg_parser.add_argument('-c', '--config', help='Configuration file',
                            default='~/.config/telegram-api.conf')
    return arg_parser.parse_args()

def load_config(filename):
    cp = configparser.ConfigParser()
    cp.read(expanduser(filename))
    return cp.get('api', 'id'), cp.get('api', 'hash')

def main(args):
    api_id, api_hash = load_config(args.config)
    cl = telethon.TelegramClient(expanduser('~/UnreadCount'), api_id, api_hash)
    cl.start()
    unread_count = sum(
        d.unread_count for d in cl.iter_dialogs()
        if (d.dialog.notify_settings.mute_until or 0) < time.time()
    )
    print(unread_count)
    cl.disconnect()

if __name__ == '__main__':
    main(parse_args())
