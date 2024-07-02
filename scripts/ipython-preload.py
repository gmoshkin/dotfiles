import msgpack
import os
import sys
import shutil
import time
import random

class progress:
    def __init__(self, iter, count=None):
        self.iter = iter.__iter__()
        if count is not None:
            self.count = count
        elif hasattr(iter, '__len__'):
            self.count = len(iter)
        else:
            self.count = '?'
        self.it = 1
        self.t0 = time.time()
        self.last_time_printed = -1

    def __next__(self):
        try:
            next = self.iter.__next__()
        except StopIteration as e:
            elapsed = pretty_duration(time.time() - self.t0)
            print(f'\x1b[0G\x1b[K{self.it - 1}/{self.it - 1}: elapsed: {elapsed}', end='')
            raise e

        now = time.time()
        if now > self.last_time_printed + 0.05:
            self.last_time_printed = now
            elapsed = pretty_duration(now - self.t0)
            print(f'\x1b[0G\x1b[K{self.it}/{self.count}: elapsed: {elapsed}', end='')
            sys.stdout.flush()
        else:
            # Don't print more than 20 times a second
            pass

        self.it += 1
        return next

    def __iter__(self):
        return self

def pretty_duration(d):
    minutes, seconds = divmod(d, 60)
    if minutes == 0:
        if seconds >= 0.001:
            return f'{seconds:.3f}s'
        elif seconds >= 0.000001:
            return f'{seconds:.6f}s'
        else:
            return f'{seconds:.9f}s'

    hours, minutes = divmod(int(minutes), 60)
    if hours == 0:
        return f'{minutes:02}:{seconds:06.3f}'
    else:
        return f'{hours:02}:{minutes:02}:{seconds:06.3f}'

def read_entire_file(filename, binary=False):
    flags = 'r'
    if binary:
        flags += 'b'
    try:
        with open(filename, flags) as f:
            return f.read()
    except UnicodeDecodeError:
        with open(filename, 'rb') as f:
            return f.read()



# TEMPORARY:
modules_not_found = []

try:
    import magic
except ModuleNotFoundError as e:
    modules_not_found.append(e.name)
try:
    import sqlite3
except ModuleNotFoundError as e:
    modules_not_found.append(e.name)
try:
    import bplist
except ModuleNotFoundError as e:
    modules_not_found.append(e.name)

if modules_not_found:
    print(f"Couldn't import modules {modules_not_found}")

source_c = '/mnt/c/Users/james/Apple/MobileSync/Backup/00008110-001E49690A07801E/'
source_d = '/mnt/d/Apple/MobileSync/Backup/00008110-001E49690A07801E/'

def full_path(fileId):
    source = os.path.join(source_c, fileId[:2], fileId)
    drive = 'c'
    if not os.path.exists(source):
        source = os.path.join(source_d, fileId[:2], fileId)
        drive = 'd'
    return source, drive

db_path = '/mnt/c/iphone-backup/Manifest.db'
db_connection = None

def sqlite_execute(sql, *args):
    global db_connection
    if db_connection is None:
        db_connection = sqlite3.connect()
    cursor = db_connection.execute(sql, args)
    return list(progress(cursor))


def move_entries(entries):
    for fId, fPath in progress(entries):
        src, drive = full_path(fId)
        directory, filename = os.path.split(fPath)
        directory = os.path.join('/mnt', drive, 'iphone-backup', directory)
        os.makedirs(directory, exist_ok=True)
        dst = os.path.join(directory, filename)
        os.rename(src, dst)

def report_copied(entries):
    with open('/mnt/d/iphone-backup/copied.csv', 'a') as f:
        for fid, fpath in entries:
            print(f'{fid},{fpath}', file=f)


def parse_plist(plist):
    return bplist.BPListReader(plist).parse()
