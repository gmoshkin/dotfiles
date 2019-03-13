import sys
from base64 import standard_b64encode

def serialize_gr_command(cmd, payload=None):
   cmd = ','.join('{}={}'.format(k, v) for k, v in cmd.items())
   ans = []
   w = ans.append
   w(b'\033_G'), w(cmd.encode('ascii'))
   if payload:
      w(b';')
      w(payload)
   w(b'\033\\')
   return b''.join(ans)

def write_chunked(cmd, data):
   data = standard_b64encode(data)
   while data:
      chunk, data = data[:4096], data[4096:]
      m = 1 if data else 0
      cmd['m'] = m
      sys.stdout.buffer.write(serialize_gr_command(cmd, chunk))
      sys.stdout.flush()
      cmd.clear()

write_chunked({'f': 100}, open(sys.argv[-1], 'rb').read())
