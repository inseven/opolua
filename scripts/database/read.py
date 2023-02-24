#!/usr/bin/env python3

import argparse
import collections
import contextlib
import os
import struct


# class FrameDes
# 	{
# 	enum {TypeMask=0xc000,TypeShift=14,LengthMask=0x3fff};
# public:
# 	enum {First=0x20,Size=2,Interval=0x4002,FullShift=14};
# 	enum {Free=0,Data,Toc,Continuation};
# //
# 	inline FrameDes() {}
# 	inline FrameDes(unsigned aDes) :iDes((unsigned short)aDes) {}
# 	inline int Type() const {return iDes>>TypeShift;}
# 	inline int Length() const {return iDes&LengthMask;}
# private:
# 	unsigned short iDes;
# //
# 	friend ostream& operator<<(ostream&,FrameDes);
# 	friend istream& operator>>(istream&,FrameDes&);
# 	};

FRAME_DESCRIPTION_FIRST = 0x20
FRAME_DESCRIPTION_SIZE = 2
FRAME_DESCRIPTION_INTERVAL = 0x4002
FRAME_DESCRIPTION_FULL_SHIFT = 14

HEADER_OFFSET = 0x10
HEADER_SIZE = 14


# K_DBMS_STORE_DATABASE = 268435561
PERMANENT_FILE_STORE_UID = 268435536



# class Handle(object):
#
#     def __init__(self, fh):
#         (self.value, ) = struct.unpack('i', fh.read(4))
#
#     def __repr__(self):
#         return f"Handle({self.value})"

# class FramePos(object):
#
#     def __init__(self, fh):
#         (self.value, ) = struct.unpack('i', fh.read(4))
#
#     def __repr__(self):
#         return f"FramePos({self.value})"


def read_int(fh):
    return struct.unpack('i', fh.read(4))


Toc = collections.namedtuple('Toc', ['zero', 'pos'])
Reloc = collections.namedtuple('Reloc', ['handle', 'pos'])
Header = collections.namedtuple('Header', ['backup_toc', 'toc', 'reloc', 'crc'])


# TODO: Rename this.
@contextlib.contextmanager
def restore_offset(fh):
    offset = fh.tell()
    try:
        yield fh
    finally:
        fh.seek(offset)


def read_short(fh):
    return struct.unpack('h', fh.read(2))[0]


def read_unsigned_short(fh):
    return struct.unpack('H', fh.read(2))[0]


def read_long(fh):
    return struct.unpack('i', fh.read(4))[0]


def read_unsigned_long(fh):
    return struct.unpack('I', fh.read(4))[0]


def read_handle(fh):
    return read_unsigned_long(fh)


def read_toc(fh):
    return Toc(zero=read_long(fh),
               pos=read_long(fh))


def read_reloc(fh):
    return Reloc(handle=read_unsigned_long(fh),
                 pos=read_long(fh))


def read_header(fh):

    # Helpfully the header format shares the same memory for the TOC and the Reloc (unclear which is valid) so we
    # read the first, reset the pointer, and read the second (I dread to think what happens if we ever need to write
    # this out).
    backup_toc = read_long(fh)
    with restore_offset(fh):
        toc = read_toc(fh)
    reloc = read_reloc(fh)
    crc = read_unsigned_short(fh)
    return Header(backup_toc=backup_toc, toc=toc, reloc=reloc, crc=crc)


# class FrameDes
# 	{
# 	unsigned short iDes;
# 	};



# FrameDes = collections.namedtuple('FrameDes', ['des'])


# TODO: This is my own magic
FrameDetails = collections.namedtuple('FrameDetails', ['pos', 'frame'])


class FrameDes(object):

    def __init__(self, des):
        self.des = des

    @property
    def length(self):
        return self.des & 0x3fff

    @property
    def type(self):
        return self.des >> 14

    def __repr__(self):
        return f"FrameDes(des={self.des})"


# TOC Head
# struct Head
# 	{
# 	enum {Size=12};
# 	inline StreamId Root() const {return StreamId(iRoot);}
# 	inline int IsDelta() const {return iRoot.IsDelta();}
# 	Handle iRoot;
# 	Handle iAvail;
# 	long iCount;
# 	};


TocHead = collections.namedtuple('TocHead', ['root', 'avail', 'count'])


class TocHead(object):

    def __init__(self, root, avail, count):
        self.root = root
        self.avail = avail
        self.count = count

    @property
    def is_delta(self):
        return (self.root & 0x80000000) > 0

    def __repr__(self):
        return f"TocHead(root={self.root}, avail={self.avail}, count={self.count})"


def read_toc_head(fh):
    return TocHead(root=read_handle(fh),
                   avail=read_handle(fh),
                   count=read_long(fh))


FRAME_TYPE_FREE = 0
FRAME_TYPE_DATA = 1
FRAME_TYPE_TOC = 2
FRAME_TYPE_CONTINUATION = 3

FRAME_TYPE_NAME = {
    FRAME_TYPE_FREE: "free",
    FRAME_TYPE_DATA: "data",
    FRAME_TYPE_TOC: "toc",
    FRAME_TYPE_CONTINUATION: "continuation",
}


def read_frame_description(fh):
    return FrameDes(des=read_unsigned_short(fh))


def main():
    parser = argparse.ArgumentParser(description="Parse ER5 database")
    parser.add_argument("database")
    options = parser.parse_args()

    with open(os.path.abspath(options.database), "rb") as fh:

        # Read 32-bit int as the uid and ensure it's a permanent file store.
        uid = struct.unpack('i', fh.read(4))[0]
        assert uid == PERMANENT_FILE_STORE_UID

        # Seek to the end of the stream, get the current offset, and use this to determine the size of the file.
        fh.seek(0, 2)
        size = fh.tell()

        # Ensure the file has at least a minimum size.
        assert size >= FRAME_DESCRIPTION_FIRST

        # TODO: There's some weird thing going on with OutWidth.

        # Seek to the header.
        fh.seek(HEADER_OFFSET)
        header = read_header(fh)

        # TODO: Read the frames.

        offset = FRAME_DESCRIPTION_FIRST
        full = FRAME_DESCRIPTION_FIRST + FRAME_DESCRIPTION_INTERVAL  # TODO: What is 'full'?
        diff = FRAME_DESCRIPTION_FIRST

        # Read in a tight loop while we still have space left to read a full frame description.
        # Oddly, in the original Symbian source code, the frame description always exists before the offset, so this
        # guard looks a little strange.

        frames = {}

        # Pretty sure this is iterating over the frames in the file in order, storing their offset, and ensuring that
        # frames never exceed the maximum frame size (FRAME_DESCRIPTION_INTERVAL).
        while (offset - FRAME_DESCRIPTION_SIZE) < size:

            # If we've reached the end of the frame, then we update the 'full', and 'diff' values in advance of
            # processing.
            if offset == full:
                full += FRAME_DESCRIPTION_INTERVAL
                diff += FRAME_DESCRIPTION_SIZE

            # If the offset matches the size of the file, we might have a valid frame description, but there's no frame
            # to read, so we exit early. This is another weird side effect of the way the original Symbian code was
            # written.
            if offset > size:
                break

            # Seek to the frame description for the first offset and read it.
            fh.seek(offset - FRAME_DESCRIPTION_SIZE)
            frame = read_frame_description(fh)

            # N.B. The offset is always the actual start of the frame (+first-desc_size). What the heck is this code
            # doing?
            # frames[frame] = FrameDetails(offset=offset-diff, frame=frame)
            # frames.append(FrameDetails(pos=offset-diff, frame=frame))
            frames[offset-diff] = frame

            # Guard against zero length frames.
            # TODO: Maybe we should actually exit here with a corrupt database (I wonder how often it happens).
            if frame.length == 0:
                offset = full  # We assume our frame consumes the whole block and jump to the next one.
                print("WARNING")
                continue

            new_offset = offset + frame.length + FRAME_DESCRIPTION_SIZE

            # Ensure the new offset doesn't exceed a stride (perhaps it would be more elegant to guard the length of the
            # frame instead?
            # N.B. The later check shouldn't be necessary as this look exits in this scenario anyhow.
            if (new_offset >= full) or (new_offset - FRAME_DESCRIPTION_SIZE > size):
                print("ERROR")
                offset = full
                continue

            offset = new_offset
            # Snap back to the bounds.
            if full - offset <= FRAME_DESCRIPTION_SIZE:
                offset = full

        print(header)
        print(repr(frames))

        # for frame in frames:
        #     print(FRAME_TYPE_NAME[frame.frame.type])

        import pprint
        pprint.pprint(frames)


        # Load the TOC.
        # This does not make any attempt to load from the backup TOC (which we could do if we found files were corrupt).
        # Unhelpfully, the TOC is actually always at an offset of -12 bytes from where it reports itself to be. I
        # presume this is because the TOC is 12 bytes and reports its end address, not its start (sigh).
        toc_offset = header.toc.pos - 12
        toc = frames[toc_offset]
        assert toc.type == FRAME_TYPE_TOC
        print(toc)

        # The example code I've been looking at also has support for finding a specific TOC revision, but we don't seem
        # to need that here, so this just accepts the TOC the header points to.

        fh.seek(toc_offset)
        toc_head = read_toc_head(fh)
        print(toc_head)

        assert toc_head.count > 0
        print(toc_head.is_delta)

        print(toc.length)
        print(toc_head.count)
        assert toc.length == (12 + toc_head.count) * 5






if __name__ == "__main__":
    main()
