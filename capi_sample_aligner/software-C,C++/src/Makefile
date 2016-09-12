# (c) Copyright International Business Machines 2014

# this is the location of the Power Service Layer Simulation Engine libcxl
# this example assumes you've extracted the demo in the same directory in which you
# extracted the PSLSE
PSLSE_DIR=../../pslse-master/libcxl # CHANGE(ilir)-20/06/2016: replaced /pslse with /libcxl (required libcxl.h)
OBJ_DIR=../build
IDIR= ../include
CFLAGS += -O2 -Wall -m64
LIBCFLAGS += -O2 -Wall -m64
#CFLAGS += -g -Wall -m64
#LIBCFLAGS += -g -Wall -m64 -DDEBUG
PSL_FLAGS= $(LIBCFLAGS) -I$(PSL_DIR)
APP=main_test
ISRC=aligner_Header.c
all: ${APP}

${APP} : ${APP}.c
	${CC} ${APP}.c ${IDIR}/${ISRC} -o $(OBJ_DIR)/$@ ${CFLAGS} -L${PWD} -L${PSLSE_DIR} -L${IDIR} -I${PWD} -I${PSLSE_DIR} -I${IDIR} -lm -lcxl -lpthread -lrt

#shim_host.dat:
#	$(error 'Please symlink shim_host.dat ususally from ./pslse-master/pslse/shim_host.dat')

clean:
	/bin/rm -f $(OBJ_DIR)/${APP} $(OBJ_DIR)*.a $(OBJ_DIR)/*.o
