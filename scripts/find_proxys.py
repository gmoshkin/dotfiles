#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import requests
import bs4

bs = bs4.BeautifulSoup(requests.get('https://www.socks-proxy.net/').text)

for tr in bs.find(id='proxylisttable')('tr'):
    try:
        ip, port, code, country, version, anonymity, https, last_check = (
            t.text for t in tr('td')
        )
        if version == 'Socks5':
            print('[%s %s]: socks5://%s:%s' % (country, last_check, ip, port))
    except ValueError:
        continue
