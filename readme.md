## 플러터 Serial Example (윈도우,리눅스)
FFI를 이용해 네이티브 코드 가져다 쓰기

#### 폴더 설명
```
serialport - 시리얼 포트 윈도우 dll 소스코드(Visual Studio 2022로 빌드함)
serial_example - 플러터 소스코드
```


#### 리눅스 (아직 작업 안됨)
```
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <termios.h>
#include <unistd.h>

int openSerialPort(const char *portName, int baudRate, int byteSize, int parity, int stopBits) {
    int fd = open(portName, O_RDWR | O_NOCTTY | O_SYNC);
    if (fd < 0) {
        return -1;
    }

    struct termios tty;
    memset(&tty, 0, sizeof tty);
    if (tcgetattr(fd, &tty) != 0) {
        close(fd);
        return -1;
    }

    cfsetospeed(&tty, baudRate);
    cfsetispeed(&tty, baudRate);

    tty.c_cflag = (tty.c_cflag & ~CSIZE) | byteSize;
    tty.c_cflag |= (CLOCAL | CREAD);

    tty.c_cflag &= ~(PARENB | PARODD);
    if (parity != 0) {
        tty.c_cflag |= PARENB;
        if (parity == 1) {
            tty.c_cflag |= PARODD;
        }
    }

    if (stopBits == 2) {
        tty.c_cflag |= CSTOPB;
    } else {
        tty.c_cflag &= ~CSTOPB;
    }

    tty.c_cflag &= ~CRTSCTS;
    tty.c_iflag &= ~(IXON | IXOFF | IXANY);

    tty.c_lflag = 0;
    tty.c_oflag = 0;

    tty.c_cc[VMIN] = 1;
    tty.c_cc[VTIME] = 5;

    if (tcsetattr(fd, TCSANOW, &tty) != 0) {
        close(fd);
        return -1;
    }

    return fd;
}

void closeSerialPort(int fd) {
    close(fd);
}

int writeSerialPort(int fd, const char *data, int length) {
    return write(fd, data, length);
}

int readSerialPort(int fd, char *buffer, int bufferSize) {
    return read(fd, buffer, bufferSize);
}
```

#### 빌드 방법
```
gcc -shared -o libserialport.so -fPIC serial_port.c
```

#### so 파일 위치
```
serial_example/lib/linux/libserialport.so
```

