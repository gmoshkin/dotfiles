import msgpack
import os
import sys
import shutil
import time
import random
import datetime

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


def pretty_size(s):
    if s < 1000:
        return f'{s}B'

    if s < 1000 * 1000:
        k = s / 1000
        return f'{k:.1f}K'

    if s < 1000 * 1000 * 1000:
        m = s / 1000 / 1000
        return f'{m:.1f}M'

    if s < 1000 * 1000 * 1000 * 1000:
        g = s / 1000 / 1000 / 1000
        return f'{g:.1f}G'

    t = s / 1000 / 1000 / 1000 / 1000
    return f'{t:.1f}T'


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

try:
    from pillow_heif import register_heif_opener
    register_heif_opener()
except ModuleNotFoundError as e:
    modules_not_found.append(e.name)

if modules_not_found:
    print(f"Couldn't import modules {modules_not_found}")

# TEMPORARY:

dcim_location = '/mnt/d/фото/с айфона 02.07.24/DCIM'
photos_db_path = '/mnt/d/iphone-backup/Photos.sqlite'
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


tens_twenty_to_fifty = { 2: 'twenty', 3: 'thirty', 4: 'forty', 5: 'fifty' }
one_to_nineteen = {
    1: 'one', 2: 'two', 3: 'three', 4: 'four', 5: 'five', 6: 'six', 7: 'seven', 8: 'eight', 9: 'nine', 10: 'ten',
    11: 'eleven', 12: 'twelve', 13: 'thirteen', 14: 'fourteen', 15: 'fifteen', 16: 'sixteen', 17: 'seventeen', 18: 'eighteen', 19: 'nineteen',
}
def spell_out(number: int) -> str:
    if number == 0:
        return 'zero'
    rest = number
    assert rest < 1000_000_000_000

    pieces = []

    billions, rest = divmod(rest, 1000_000_000)
    if billions > 0:
        pieces.append(spell_out(billions) + ' billion')

    millions, rest = divmod(rest, 1000_000)
    if millions > 0:
        pieces.append(spell_out(millions) + ' million')

    thousands, rest = divmod(rest, 1000)
    if thousands > 0:
        pieces.append(spell_out(thousands) + ' thousand')

    hundreds, rest = divmod(rest, 100)
    if hundreds > 0:
        pieces.append(spell_out(hundreds) + ' hundred')

    if not rest:
        return ' '.join(pieces)

    if pieces:
        pieces.append('and')

    tens, ones = divmod(rest, 10)
    if tens > 1:
        if tens > 5:
            pieces.append(spell_out(tens) + 'ty')
        else:
            pieces.append(tens_twenty_to_fifty[tens])
        if ones > 0:
            pieces.append(one_to_nineteen[ones])
    else: # tens <= 1
        pieces.append(one_to_nineteen[rest])

    return ' '.join(pieces)

def hex_to_bytes(s):
    return bytes(int(a + b, 16) for a, b in zip(s[0::2], s[1::2]))

ORD_BSLASH = ord('\\')
ORD_DQUOTE = ord('"')
ORD_SPACE = ord('"')
ORD_TILDE = ord('~')

def byte_to_hex(c):
    return (f'\\{chr(c)}' if c == ORD_BSLASH or c == ORD_DQUOTE else chr(c) if ORD_SPACE <= c <= ORD_TILDE else f'\\x{c:02x}')

def bytes_to_hex(b):
    return 'b"{}"'.format(''.join(map(byte_to_hex, b)))

def color_fg_256(c):
    return f'\x1b[38;5;{c}m'

def color_bg_256(c):
    return f'\x1b[48;5;{c}m'

class Color_256:
    TRANSPARENT    = 0;
    RED            = 1;
    GREEN          = 2;
    YELLOW         = 3;
    BLUE           = 4;
    MAGENTA        = 5;
    CYAN           = 6;
    WHITE          = 7;
    BRIGHT_BLACK   = 8;
    BRIGHT_RED     = 9;
    BRIGHT_GREEN   = 10;
    BRIGHT_YELLOW  = 11;
    BRIGHT_BLUE    = 12;
    BRIGHT_MAGENTA = 13;
    BRIGHT_CYAN    = 14;
    BRIGHT_WHITE   = 15;

    # The formula for these is `16 + r * 36 + g * 6 + b` where r, g & b are in 0..5 inclusively
    RGB_0_0_0 =  16; RGB_0_0_1 =  17; RGB_0_0_2 =  18; RGB_0_0_3 =  19; RGB_0_0_4 =  20; RGB_0_0_5 =  21;
    RGB_0_1_0 =  22; RGB_0_1_1 =  23; RGB_0_1_2 =  24; RGB_0_1_3 =  25; RGB_0_1_4 =  26; RGB_0_1_5 =  27;
    RGB_0_2_0 =  28; RGB_0_2_1 =  29; RGB_0_2_2 =  30; RGB_0_2_3 =  31; RGB_0_2_4 =  32; RGB_0_2_5 =  33;
    RGB_0_3_0 =  34; RGB_0_3_1 =  35; RGB_0_3_2 =  36; RGB_0_3_3 =  37; RGB_0_3_4 =  38; RGB_0_3_5 =  39;
    RGB_0_4_0 =  40; RGB_0_4_1 =  41; RGB_0_4_2 =  42; RGB_0_4_3 =  43; RGB_0_4_4 =  44; RGB_0_4_5 =  45;
    RGB_0_5_0 =  46; RGB_0_5_1 =  47; RGB_0_5_2 =  48; RGB_0_5_3 =  49; RGB_0_5_4 =  50; RGB_0_5_5 =  51;

    RGB_1_0_0 =  52; RGB_1_0_1 =  53; RGB_1_0_2 =  54; RGB_1_0_3 =  55; RGB_1_0_4 =  56; RGB_1_0_5 =  57;
    RGB_1_1_0 =  58; RGB_1_1_1 =  59; RGB_1_1_2 =  60; RGB_1_1_3 =  61; RGB_1_1_4 =  62; RGB_1_1_5 =  63;
    RGB_1_2_0 =  64; RGB_1_2_1 =  65; RGB_1_2_2 =  66; RGB_1_2_3 =  67; RGB_1_2_4 =  68; RGB_1_2_5 =  69;
    RGB_1_3_0 =  70; RGB_1_3_1 =  71; RGB_1_3_2 =  72; RGB_1_3_3 =  73; RGB_1_3_4 =  74; RGB_1_3_5 =  75;
    RGB_1_4_0 =  76; RGB_1_4_1 =  77; RGB_1_4_2 =  78; RGB_1_4_3 =  79; RGB_1_4_4 =  80; RGB_1_4_5 =  81;
    RGB_1_5_0 =  82; RGB_1_5_1 =  83; RGB_1_5_2 =  84; RGB_1_5_3 =  85; RGB_1_5_4 =  86; RGB_1_5_5 =  87;

    RGB_2_0_0 =  88; RGB_2_0_1 =  89; RGB_2_0_2 =  90; RGB_2_0_3 =  91; RGB_2_0_4 =  92; RGB_2_0_5 =  93;
    RGB_2_1_0 =  94; RGB_2_1_1 =  95; RGB_2_1_2 =  96; RGB_2_1_3 =  97; RGB_2_1_4 =  98; RGB_2_1_5 =  99;
    RGB_2_2_0 = 100; RGB_2_2_1 = 101; RGB_2_2_2 = 102; RGB_2_2_3 = 103; RGB_2_2_4 = 104; RGB_2_2_5 = 105;
    RGB_2_3_0 = 106; RGB_2_3_1 = 107; RGB_2_3_2 = 108; RGB_2_3_3 = 109; RGB_2_3_4 = 110; RGB_2_3_5 = 111;
    RGB_2_4_0 = 112; RGB_2_4_1 = 113; RGB_2_4_2 = 114; RGB_2_4_3 = 115; RGB_2_4_4 = 116; RGB_2_4_5 = 117;
    RGB_2_5_0 = 118; RGB_2_5_1 = 119; RGB_2_5_2 = 120; RGB_2_5_3 = 121; RGB_2_5_4 = 122; RGB_2_5_5 = 123;

    RGB_3_0_0 = 124; RGB_3_0_1 = 125; RGB_3_0_2 = 126; RGB_3_0_3 = 127; RGB_3_0_4 = 128; RGB_3_0_5 = 129;
    RGB_3_1_0 = 130; RGB_3_1_1 = 131; RGB_3_1_2 = 132; RGB_3_1_3 = 133; RGB_3_1_4 = 134; RGB_3_1_5 = 135;
    RGB_3_2_0 = 136; RGB_3_2_1 = 137; RGB_3_2_2 = 138; RGB_3_2_3 = 139; RGB_3_2_4 = 140; RGB_3_2_5 = 141;
    RGB_3_3_0 = 142; RGB_3_3_1 = 143; RGB_3_3_2 = 144; RGB_3_3_3 = 145; RGB_3_3_4 = 146; RGB_3_3_5 = 147;
    RGB_3_4_0 = 148; RGB_3_4_1 = 149; RGB_3_4_2 = 150; RGB_3_4_3 = 151; RGB_3_4_4 = 152; RGB_3_4_5 = 153;
    RGB_3_5_0 = 154; RGB_3_5_1 = 155; RGB_3_5_2 = 156; RGB_3_5_3 = 157; RGB_3_5_4 = 158; RGB_3_5_5 = 159;

    RGB_4_0_0 = 160; RGB_4_0_1 = 161; RGB_4_0_2 = 162; RGB_4_0_3 = 163; RGB_4_0_4 = 164; RGB_4_0_5 = 165;
    RGB_4_1_0 = 166; RGB_4_1_1 = 167; RGB_4_1_2 = 168; RGB_4_1_3 = 169; RGB_4_1_4 = 170; RGB_4_1_5 = 171;
    RGB_4_2_0 = 172; RGB_4_2_1 = 173; RGB_4_2_2 = 174; RGB_4_2_3 = 175; RGB_4_2_4 = 176; RGB_4_2_5 = 177;
    RGB_4_3_0 = 178; RGB_4_3_1 = 179; RGB_4_3_2 = 180; RGB_4_3_3 = 181; RGB_4_3_4 = 182; RGB_4_3_5 = 183;
    RGB_4_4_0 = 184; RGB_4_4_1 = 185; RGB_4_4_2 = 186; RGB_4_4_3 = 187; RGB_4_4_4 = 188; RGB_4_4_5 = 189;
    RGB_4_5_0 = 190; RGB_4_5_1 = 191; RGB_4_5_2 = 192; RGB_4_5_3 = 193; RGB_4_5_4 = 194; RGB_4_5_5 = 195;

    RGB_5_0_0 = 196; RGB_5_0_1 = 197; RGB_5_0_2 = 198; RGB_5_0_3 = 199; RGB_5_0_4 = 200; RGB_5_0_5 = 201;
    RGB_5_1_0 = 202; RGB_5_1_1 = 203; RGB_5_1_2 = 204; RGB_5_1_3 = 205; RGB_5_1_4 = 206; RGB_5_1_5 = 207;
    RGB_5_2_0 = 208; RGB_5_2_1 = 209; RGB_5_2_2 = 210; RGB_5_2_3 = 211; RGB_5_2_4 = 212; RGB_5_2_5 = 213;
    RGB_5_3_0 = 214; RGB_5_3_1 = 215; RGB_5_3_2 = 216; RGB_5_3_3 = 217; RGB_5_3_4 = 218; RGB_5_3_5 = 219;
    RGB_5_4_0 = 220; RGB_5_4_1 = 221; RGB_5_4_2 = 222; RGB_5_4_3 = 223; RGB_5_4_4 = 224; RGB_5_4_5 = 225;
    RGB_5_5_0 = 226; RGB_5_5_1 = 227; RGB_5_5_2 = 228; RGB_5_5_3 = 229; RGB_5_5_4 = 230; RGB_5_5_5 = 231;

    # 0 is black, 23 is white
    GRAY_0  = 232; GRAY_1  = 233; GRAY_2  = 234; GRAY_3  = 235; GRAY_4  = 236; GRAY_5  = 237;
    GRAY_6  = 238; GRAY_7  = 239; GRAY_8  = 240; GRAY_9  = 241; GRAY_10 = 242; GRAY_11 = 243;
    GRAY_12 = 244; GRAY_13 = 245; GRAY_14 = 246; GRAY_15 = 247; GRAY_16 = 248; GRAY_17 = 249;
    GRAY_18 = 250; GRAY_19 = 251; GRAY_20 = 252; GRAY_21 = 253; GRAY_22 = 254; GRAY_23 = 255;

def get_exif(img):
    from PIL import Image
    from PIL.ExifTags import TAGS

    if isinstance(img, str):
        img = Image.open(img)

    res = {}
    for k, v in img.getexif().items():
        tag = TAGS.get(k, v)
        assert tag not in res
        res[tag] = v

def get_img_files():
    files = []
    for d in progress(os.listdir(dcim_location)):
        for f in os.listdir(os.path.join(dcim_location, d)):
            files.append(os.path.join(dcim_location, d, f))
    return files


def creation_date_from_exiftool(filepath):
    import subprocess
    res = None
    data = subprocess.check_output(['exiftool', filepath])
    for l in data.splitlines():
        if not l.startswith(b'Create Date'):
            continue
        _, payload = l.split(b':', maxsplit=1)
        payload = payload.strip().decode()
        if res is None or len(payload) > len(res):
            res = payload
    return res

photos_conn = None
def photos_sql(sql, *args, progress=True):
    global photos_conn
    if photos_conn is None:
        photos_conn = sqlite3.connect(photos_db_path)
    cursor = photos_conn.execute(sql, args)
    if progress:
        cursor = progress(cursor)
    return list(cursor)

def check_creation_dates(files):
    res = []
    for e in progress(files):
        full_directory, f = os.path.split(e)
        _, d = os.path.split(full_directory)
        rows = photos_sql('select zdatecreated from zasset where zdirectory = ? and zfilename = ?', f'DCIM/{d}', f, progress=False)
        [[timestamp]] = rows
        date = datetime.datetime.fromtimestamp(timestamp)

        from_exif = creation_date_from_exiftool(e)
        res.append(f'{e}: {date}, {from_exif}')
    return res
