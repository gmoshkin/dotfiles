#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import requests
import json
import argparse
import configparser
import os

def parse_args():
    arg_parser = argparse.ArgumentParser(description='Get lat,lng by address string')
    arg_parser.add_argument('address', nargs='+', help='address string')
    return arg_parser.parse_args()

def get_api_key():
    conf = configparser.ConfigParser()
    conf.read(os.path.expanduser('~/.config/google-api-keys.conf'))
    return conf.get('geocode', 'key')


def main(args):
    if not args.address:
        return
    request_params = {
        'address': ' '.join(args.address),
        'key': get_api_key(),
    }
    url = 'https://maps.googleapis.com/maps/api/geocode/json'
    r = requests.get(url, params=request_params)
    data = json.loads(r.text)
    if data['status'] != 'OK':
        print('Error!', data)
        return
    for res in data['results']:
        print('{lat},{lng}'.format(**res['geometry']['location']))

if __name__ == '__main__':
    args = parse_args()
    main(args)
