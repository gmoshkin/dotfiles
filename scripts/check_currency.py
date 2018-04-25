#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import configparser
import requests
import json
import os
import telegram_send
import argparse

def parse_args():
    arg_parser = argparse.ArgumentParser(description=(
        'Check the current USD/RUB exchange rate and show what I would gain '
        'if I were to sell now'
    ))
    arg_parser.add_argument('-tg', help='Send result as a message to telegram',
                            action='store_true')
    arg_parser.add_argument('-itg', help=('Send result as a message to telegram'
                                          ' (via integram)'),
                            action='store_true')
    return arg_parser.parse_args()

ALPHAVANTAGE_URL = 'https://www.alphavantage.co/query'
ALPHAVANTAGE_FUNCTION = 'CURRENCY_EXCHANGE_RATE'

conf = None

def get_conf():
    global conf
    if conf is None:
        conf = configparser.ConfigParser()
    conf.read(os.path.expanduser('~/.config/currency.conf'))
    return conf

def get_api_key():
    return get_conf().get('alphavantage', 'apikey')

def get_sums():
    return tuple(float(get_conf().get('sum', _)) for _ in ['usd', 'rub'])

def integram(message):
    requests.post('https://integram.org/' + os.environ['INTEGRAM_TOKEN'],
                  data={'payload': json.dumps({'text': message})})

def main(args):
    params = {
        'apikey' : get_api_key(),
        'from_currency' : 'USD',
        'to_currency' : 'RUB',
        'function' : ALPHAVANTAGE_FUNCTION,
    }
    r = requests.get(ALPHAVANTAGE_URL, params=params)
    data = json.loads(r.text)
    # text = '''
# {
    # "Realtime Currency Exchange Rate": {
    #     "1. From_Currency Code": "USD",
    #     "2. From_Currency Name": "United States Dollar",
    #     "3. To_Currency Code": "RUB",
    #     "4. To_Currency Name": "Russian Ruble",
    #     "5. Exchange Rate": "56.98890000",
    #     "6. Last Refreshed": "2018-03-26 12:41:17",
    #     "7. Time Zone": "UTC"
    # }
# }
    # '''
    # data = json.loads(text)
    rate = float(data["Realtime Currency Exchange Rate"]["5. Exchange Rate"])
    have_usd, want_rub = get_sums()
    will_have_rub = have_usd * rate
    diff = will_have_rub - want_rub
    message = 'USD {}\nПрибыль: {:.02f}₽'.format(rate, diff)
    failed = False
    if args.tg:
        try:
            telegram_send.send([message], timeout=3.0)
        except:
            failed = True
    if args.itg or failed:
        integram(message)
    print(message)


if __name__ == '__main__':
    main(parse_args())
