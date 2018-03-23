#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import telegram
import telegram_send
import configparser

if __name__ == '__main__':
    config = configparser.ConfigParser()
    config.read(telegram_send.get_config_path())

    request = telegram.utils.request.Request(read_timeout=30)
    bot = telegram.Bot(config.get('telegram', 'token'), request=request)
    updates = bot.get_updates(offset=None, timeout=10)
    for update in updates:
        if update.message:
            print('[{}] {}: {}'.format(update.message.date.strftime('%d/%m %H:%M'),
                                       update.message.from_user.username,
                                       update.message.text))
