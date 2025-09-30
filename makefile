#My device is a Macbook Air
CC = gcc

OPENBLAS_PATH = /opt/homebrew/Cellar/openblas/0.3.30
LIBOMP_PATH = /opt/homebrew/opt/libomp

CPPFLAGS = -I$(OPENBLAS_PATH)/include -I$(LIBOMP_PATH)/include
LDFLAGS  = -L$(LIBOMP_PATH)/lib
LDLIBS   = $(OPENBLAS_PATH)/lib/libopenblas.a -lomp

OBJ = dgesv.o timer.o main.o
TARGET = dgesv

$(TARGET): $(OBJ)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

%.o: %.c
	$(CC) $(CPPFLAGS) -c $< -o $@

clean:
	rm -f $(TARGET) $(OBJ)
