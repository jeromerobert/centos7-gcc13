FROM centos:7 as base

# Git
FROM base as git
RUN curl -kLO https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.42.0.tar.xz
RUN sha256sum *.tar.xz
RUN echo "3278210e9fd2994b8484dd7e3ddd9ea8b940ef52170cdb606daa94d887c93b0d " *.tar.* | sha256sum -c -
RUN tar xf *.tar.xz
WORKDIR git-2.42.0
RUN yum -y install gcc make zlib-devel gettext libcurl-devel
RUN ./configure --prefix=/usr/local
RUN make -j $(nproc)
RUN make NO_INSTALL_HARDLINKS=YesPlease install

# Binutils
FROM base as binutils
RUN curl -LO https://ftp.gnu.org/gnu/binutils/binutils-2.41.tar.xz
RUN sha256sum binutils*.tar.*
RUN echo "ae9a5789e23459e59606e6714723f2d3ffc31c03174191ef0d015bdf06007450 " binutils*.tar.* | sha256sum -c -
RUN tar xf binutils*.tar.*
WORKDIR build-binutils
RUN yum -y install gcc-c++ make zlib-devel gettext bison texinfo
RUN ../binutils*/configure
RUN make -j$(nproc)
RUN make install

# GMP
FROM base as gmp
RUN curl -LO https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz
RUN sha256sum gmp*.tar.*
RUN echo "fd4829912cddd12f84181c3451cc752be224643e87fac497b69edddadc49b4f2 " gmp*.tar.* | sha256sum -c -
RUN tar xf gmp*.tar.*
WORKDIR build-gmp
RUN yum -y install gcc make m4
RUN ../gmp*/configure
RUN make -j$(nproc)
RUN make install

# mpfr
FROM base as mpfr
RUN curl -LO https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.0.tar.xz
RUN sha256sum mpfr*.tar.*
RUN echo "06a378df13501248c1b2db5aa977a2c8126ae849a9d9b7be2546fb4a9c26d993 " mpfr*.tar.* | sha256sum -c -
RUN tar xf mpfr*.tar.*
WORKDIR build-mpfr
RUN yum -y install gcc make
COPY --from=gmp /usr/local/ /usr/local/
RUN ../mpfr*/configure
RUN make -j$(nproc)
RUN before=$(find /usr/local -type f ; find /usr/local -type l ; find /usr/local -type d -empty) ; \
    make install ; rm -rf $before

# mpc
FROM base as mpc
RUN curl -LO https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz
RUN sha256sum mpc*.tar.*
RUN echo "ab642492f5cf882b74aa0cb730cd410a81edcdbec895183ce930e706c1c759b8 " mpc*.tar.* | sha256sum -c -
RUN tar xf mpc*.tar.*
WORKDIR build-mpc
RUN yum -y install gcc make
COPY --from=mpfr /usr/local/ /usr/local/
COPY --from=gmp /usr/local/ /usr/local/
RUN ../mpc*/configure
RUN make -j$(nproc)
RUN before=$(find /usr/local -type f ; find /usr/local -type l ; find /usr/local -type d -empty) ; \
    make install ; rm -rf $before

# OpenSSL
FROM base as openssl
RUN curl -LO https://www.openssl.org/source/openssl-3.0.10.tar.gz
RUN sha256sum openssl*.tar.gz
RUN echo "1761d4f5b13a1028b9b6f3d4b8e17feb0cedc9370f6afe61d7193d2cdce83323 " openssl*.tar.gz | sha256sum -c -
RUN tar xf openssl*.tar.gz
WORKDIR openssl-3.0.10
RUN yum -y install gcc make perl-IPC-Cmd
RUN ./config --prefix=/usr/local --openssldir=/usr/local shared
RUN make -j$(nproc)
RUN make install_sw install_ssldirs

# cmake
FROM base as cmake
RUN curl -kLO https://github.com/Kitware/CMake/releases/download/v3.27.4/cmake-3.27.4.tar.gz
RUN sha256sum cmake-*.tar.gz
RUN echo "0a905ca8635ca81aa152e123bdde7e54cbe764fdd9a70d62af44cad8b92967af " cmake-*.tar.gz | sha256sum -c -
RUN tar xf *.tar.gz
WORKDIR cmake-3.27.4
RUN yum -y install gcc-c++ make
COPY --from=openssl /usr/local/ /usr/local/
RUN ./bootstrap --parallel=$(nproc)
RUN make -j$(nproc)
RUN before=$(find /usr/local -type f ; find /usr/local -type l ; find /usr/local -type d -empty) ; \
    make install ; rm -rf $before

# Autotools
FROM base as autotools
RUN curl -kLO https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.xz
RUN curl -kLO https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.xz
RUN curl -kLO https://ftp.gnu.org/gnu/libtool/libtool-2.4.7.tar.xz
RUN sha256sum *.tar.*
RUN echo "f14c83cfebcc9427f2c3cea7258bd90df972d92eb26752da4ddad81c87a0faa4 " autoconf*.tar.* | sha256sum -c -
RUN echo "f01d58cd6d9d77fbdca9eb4bbd5ead1988228fdb73d6f7a201f5f8d6b118b469 " automake*.tar.* | sha256sum -c -
RUN echo "4f7f217f057ce655ff22559ad221a0fd8ef84ad1fc5fcb6990cecc333aa1635d " libtool*.tar.* | sha256sum -c -
RUN tar xf autoconf*.tar.*
RUN tar xf automake*.tar.*
RUN tar xf libtool*.tar.*
RUN yum -y install m4 make perl-Data-Dumper perl-Thread-Queue gcc
WORKDIR /autoconf-2.71
RUN ./configure
RUN make -j$(nproc)
RUN make install
WORKDIR /automake-1.16.5
RUN ./configure
RUN make -j$(nproc)
RUN make install
WORKDIR /libtool-2.4.7
RUN ./configure
RUN make -j$(nproc)
RUN make install

#hwloc
FROM base as hwloc
RUN curl -kLO https://download.open-mpi.org/release/hwloc/v2.9/hwloc-2.9.2.tar.gz
RUN sha256sum *.tar.*
RUN echo "ffb554d5735e0e0a19d1fd4b2b86e771d3b58b2d97f257eedacae67ade5054b3 " *.tar.* | sha256sum -c -
RUN tar xf *.tar.*
WORKDIR hwloc-2.9.2
RUN yum -y install gcc make
RUN ./configure
RUN make -j$(nproc)
RUN make install

# gcc
FROM base as gcc
RUN curl -kLO https://sourceware.org/pub/gcc/releases/gcc-13.2.0/gcc-13.2.0.tar.xz
RUN sha256sum *.tar.*
RUN echo "e275e76442a6067341a27f04c5c6b83d8613144004c0413528863dc6b5c743da " *.tar.* | sha256sum -c -
RUN tar xf *.tar.*
WORKDIR build-gcc
RUN yum -y install gcc-c++ make
COPY --from=binutils /usr/local/ /usr/local/
COPY --from=gmp /usr/local/ /usr/local/
COPY --from=mpfr /usr/local/ /usr/local/
COPY --from=mpc /usr/local/ /usr/local/
RUN echo -e '/usr/local/lib\n/usr/local/lib64' > /etc/ld.so.conf.d/local.conf && ldconfig
# Use symlinks instead of hardlinks because hardlinks get duplicated in the stripping stage
RUN sed -i 's/LN=@LN@/LN=@LN_S@/g' /gcc-*/gcc/Makefile.in
RUN ../gcc-*/configure --enable-languages=c,c++,fortran --disable-multilib
RUN make -j$(nproc)
RUN before=$(find /usr/local -type f ; find /usr/local -type l) ; \
    make install ; rm -rf $before $(find /usr/local -type d -empty)

# Intermediate stage for stripping
FROM base as stripped
RUN yum -y install file
COPY --from=binutils /usr/local/ /usr/local/
COPY --from=gmp /usr/local/ /usr/local/
COPY --from=mpfr /usr/local/ /usr/local/
COPY --from=mpc /usr/local/ /usr/local/
COPY --from=git /usr/local/ /usr/local/
COPY --from=openssl /usr/local/ /usr/local/
COPY --from=cmake /usr/local/ /usr/local/
COPY --from=autotools /usr/local/ /usr/local/
COPY --from=hwloc /usr/local/ /usr/local/
COPY --from=gcc /usr/local/ /usr/local/
RUN find /usr/local ! -name '*.o' -type f -exec sh -c "file -b {} | grep -Eq '^ELF.*, not stripped' && strip {}" \;

# Final stage
FROM base as final
RUN yum install -y glibc-devel make zlib-devel swig chrpath libffi-devel perl-Data-Dumper bzip2 m4 \
    perl-Thread-Queue patch mesa-libGLU-devel libXt-devel unzip libXtst libXrender libXi
COPY --from=stripped /usr/local /usr/local
RUN echo -e '/usr/local/lib\n/usr/local/lib64' > /etc/ld.so.conf.d/local.conf && ldconfig
ENV PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig
