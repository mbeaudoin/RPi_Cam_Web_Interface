
BCM_H_DIR?=/opt/vc/include/interface/

CC_OPTS=-I$(BCM_H_DIR).. \
        -I$(BCM_H_DIR)vcos/ \
	-I$(BCM_H_DIR)vcos/pthreads/ \
	-I$(BCM_H_DIR)vmcs_host/linux

CC=cc
CFLAGS=
LDFLAGS=-L /opt/vc/lib -lmmal -lmmal_core -lmmal_util -lbcm_host 

INSTALL=install

OBJ_RASPIMJPEG=RaspiMJPEG.o RaspiMCam.o  RaspiMCmds.o  RaspiMMotion.o  RaspiMUtils.o

%.o: %.c
	$(CC) -c $(CFLAGS) $(CC_OPTS) $< -o $@

all: raspimjpeg

raspimjpeg: $(OBJ_RASPIMJPEG)
	$(CC) $(CFLAGS) $(OBJ_RASPIMJPEG) -o raspimjpeg $(LDFLAGS) $(CC_OPTS)

install:
	$(INSTALL) -m 0755 -d $(DESTDIR)/opt/vc/bin
	$(INSTALL) -m 755 raspimjpeg $(DESTDIR)/opt/vc/bin
	$(INSTALL) -m 664 raspimjpeg.config $(DESTDIR)/etc/raspimjpeg

clean:
	rm -rf raspimjpeg
	rm -rf *.o *~ *.mod
