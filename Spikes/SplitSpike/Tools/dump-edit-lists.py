import struct, sys
def walk(b, s, e, depth):
    i = s
    while i + 8 <= e:
        size = struct.unpack('>I', b[i:i+4])[0]
        typ = b[i+4:i+8].decode('latin1','replace')
        hdr = 8
        if size == 1:
            size = struct.unpack('>Q', b[i+8:i+16])[0]; hdr = 16
        if size < hdr or i + size > e: break
        if typ in ('edts','elst','trak','mdia','minf','stbl','moov','mvhd','tkhd','mdhd'):
            print('  '*depth + f'{typ} size={size}')
        if typ == 'mdhd':
            body = b[i+hdr:i+size]; ver = body[0]
            if ver == 1:
                ts = struct.unpack('>I', body[20:24])[0]; dur = struct.unpack('>Q', body[24:32])[0]
            else:
                ts = struct.unpack('>I', body[12:16])[0]; dur = struct.unpack('>I', body[16:20])[0]
            print('  '*depth + f'    mdhd timescale={ts} duration={dur}')
        if typ == 'elst':
            body = b[i+hdr:i+size]; ver = body[0]
            cnt = struct.unpack('>I', body[4:8])[0]
            print('  '*depth + f'    elst version={ver} entryCount={cnt}')
            off = 8
            for _ in range(cnt):
                if ver == 1:
                    dur, mt = struct.unpack('>Qq', body[off:off+16]); off += 16
                else:
                    dur, mt = struct.unpack('>Ii', body[off:off+8]); off += 8
                rate = struct.unpack('>i', body[off:off+4])[0]; off += 4
                print('  '*depth + f'      segDuration={dur} mediaTime={mt} rate={rate/65536:.3f}')
        if typ in ('moov','trak','mdia','minf','stbl','edts'):
            walk(b, i+hdr, i+size, depth+1)
        i += size
for name in sys.argv[1:]:
    print('===', name.split('/')[-2], '===')
    b = open(name,'rb').read()
    walk(b, 0, len(b), 0)
    print()
