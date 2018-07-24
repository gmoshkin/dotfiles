#!/usr/bin/env python3.7
# -*- coding: utf-8 -*-

import configparser
from os.path import expanduser
from telethon.sync import TelegramClient
import time
import argparse
import socks

def parse_args():
    arg_parser = argparse.ArgumentParser(
        'Show unread messages count'
    )
    arg_parser.add_argument('-c', '--config', help='Configuration file',
                            default='~/.config/telegram-api.conf')
    arg_parser.add_argument('-p', '--proxy', help='Proxy configuration file',
                            default='~/.config/proxy.conf')
    return arg_parser.parse_args()

def load_config(filename):
    cp = configparser.ConfigParser()
    cp.read(expanduser(filename))
    return cp.get('api', 'id'), cp.get('api', 'hash')

def get_proxy(filename):
    cp = configparser.ConfigParser()
    cp.read(expanduser(filename))
    return dict(proxy_type=socks.SOCKS5,
                addr=cp.get('socks5', 'addr'),
                port=int(cp.get('socks5', 'port')),
                username=cp.get('login', 'username'),
                password=cp.get('login', 'password'))

def get_tg_client(config, proxy, session=expanduser('~/UnreadCount')):
    api_id, api_hash = load_config(config)
    return TelegramClient(session, api_id, api_hash, proxy=get_proxy(proxy))

def main(args):
    cl = get_tg_client(args.config, args.proxy)
    cl.start()
    unread_count = sum(
        d.unread_count for d in cl.iter_dialogs()
        if (d.dialog.notify_settings.mute_until or 0) < time.time()
    )
    print(unread_count)
    cl.disconnect()

if __name__ == '__main__':
    main(parse_args())
