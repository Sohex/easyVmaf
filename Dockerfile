FROM ubuntu:20.04

# setup timezone
ENV TZ=UTC

# setup dependencies versions

ENV	FFMPEG_version=4.2.2 \
	VMAF_version=master \
	easyVmaf_version=master 

# get and install building tools
WORKDIR	/tmp/workdir
RUN \
	ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
	apt-get update -yqq && \
	apt-get install --no-install-recommends\
                git \
		ninja-build \
		python3 \
		python3-pip \
		python3-setuptools \
		python3-wheel \
		ninja-build \
		wget \
		doxygen \
		autoconf \
		automake \
		cmake \
		g++ \
		gcc \
		pkg-config \
		make \
		nasm \
		xxd \
		yasm -y && \
	apt-get autoremove -y && \
    apt-get clean -y && \
	pip3 install --user meson && \
	rm -rf /tmp/workdir

# install libvmaf
WORKDIR     /tmp/workdir
RUN \
	export PATH="${HOME}/.local/bin:${PATH}" && \
	echo $PATH &&\
	if [ "$VMAF_version" = "master" ] ; \
	 then wget https://github.com/Netflix/vmaf/archive/${VMAF_version}.tar.gz && \
	 tar -xzf  ${VMAF_version}.tar.gz ; \
	 else wget https://github.com/Netflix/vmaf/archive/v${VMAF_version}.tar.gz && \
	 tar -xzf  v${VMAF_version}.tar.gz ; \ 
	fi && \
	cd vmaf-${VMAF_version}/libvmaf/ && \
	meson build --buildtype release && \
	ninja -vC build && \
	ninja -vC build test && \
	ninja -vC build install && \ 
	mkdir -p /usr/local/share/model  && \
	cp  -R ../model/* /usr/local/share/model && \
	rm -rf /tmp/workdir

# install libdav1d
WORKDIR  /tmp/workdir
RUN export PATH="${HOME}/.local/bin:${PATH}" && \
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib64/" && \
    export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/local/lib64/pkgconfig/" && \
    git -C dav1d pull 2> /dev/null || git clone --depth 1 https://code.videolan.org/videolan/dav1d.git && \
    mkdir -p dav1d/build && \
    cd dav1d/build && \
    meson setup -Denable_tools=false -Denable_tests=false --default-library=static .. && \
    ninja -j$(nproc) && \
    ninja install

# install ffmpeg
WORKDIR     /tmp/workdir
RUN \
	export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib64/" && \
	export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/local/lib64/pkgconfig/" && \
	wget https://ffmpeg.org/releases/ffmpeg-${FFMPEG_version}.tar.bz2 && \
	tar xjf ffmpeg-${FFMPEG_version}.tar.bz2 && \
	cd ffmpeg-${FFMPEG_version} && \
	./configure --enable-libdav1d --enable-libvmaf --enable-version3 --disable-shared && \
	make -j4 && \
	make install && \
	rm -rf /tmp/workdir

ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib64/"
# install  easyVmaf
WORKDIR  /app
RUN \
	if [ "$easyVmaf_version" = "master" ] ; \
	 then wget https://github.com/sohex/easyVmaf/archive/${easyVmaf_version}.tar.gz && \
	 tar -xzf  ${easyVmaf_version}.tar.gz ; \
	 else wget https://github.com/sohex/easyVmaf/archive/v${easyVmaf_version}.tar.gz && \
	 tar -xzf  v${easyVmaf_version}.tar.gz ; \ 
	fi && \
        mv /app/easyVmaf-${easyVmaf_version} /app/easyVmaf

# app setup
VOLUME ["/videos"]
WORKDIR  /videos
ENTRYPOINT [ "python3", "/app/easyVmaf/easyVmaf.py" ]
