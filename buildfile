## Get latest version
FROM stretch minimal rock64 latest arm64

RUN echo "This is a test" && \
	echo "& this is another test"

## Locale
RUN locale-gen "en_US.UTF-8"; \
	sed -i -e "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen; \
	echo LANG=en_US.UTF-8 > /etc/default/locale; \
	echo LC_ALL=en_US.UTF-8 > /etc/environment; \
	echo LANG=en_US.UTF-8 /etc/environment; \
	dpkg-reconfigure --frontend=noninteractive locales; \
	update-locale LANG=en_US.UTF-8

## Update
RUN apt-get update



## Required Tools
RUN apt-get install -y ipcalc

## WWAN
COPY scripts/wwan-connect /usr/bin/wwan-connect
RUN apt-get install -y modemmanager; \
	chmod +x /usr/bin/wwan-connect; \
	echo '* * * * * /usr/bin/wwan-connect' >> /var/spool/cron/crontabs/root

## WLAN
RUN cp /lib/udev/rules.d/80-net-setup-link.rules /etc/udev/rules.d/; \
	sed -i 's/ID_NET_NAME/ID_NET_SLOT/g' /etc/udev/rules.d/80-net-setup-link.rules; \
	wget https://files.evilbunny.org/rtl8812au-dkms_5.20.2-1_all.deb -O /usr/src/rtl8812au-dkms_5.20.2-1_all.deb && \
	apt-get install -y dkms && \
	dpkg -i /usr/src/rtl8812au-dkms_5.20.2-1_all.deb

## Access Point
RUN sed -i -e "s/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/" /etc/sysctl.conf; \
	sed -i -e "s/swapaccount=1/swapaccount=1 net.ifnames=0 biosdevname=0/" /boot/efi/extlinux/extlinux.conf; \
	apt-get install -y hostapd
COPY scripts/hostapd.conf /etc/hostapd/hostapd.conf
COPY scripts/interface.wlan0 /etc/network/interfaces.d/wlan0

## DHCP / DNS
RUN apt-get install -y dnsmasq; \
	mkdir -p /etc/dnsmasq.d
COPY scripts/dnsmasq.conf /etc/dnsmasq.conf
COPY scripts/dnsmasq.logging.conf /etc/dnsmasq.d/logging.conf

## OpenVPN
RUN apt-get install -y openvpn

## Clean-up
RUN apt-get -y dist-upgrade; apt-get -y autoremove; apt-get -y clean; \
	dpkg --purge \
		alsa-utils \
		avahi-daemon \
		firmware-brcm80211 \
		jq \
		libasound2 \
		libasound2-data \
		libavahi-common3 \
		libavahi-common-data \
		libavahi-core7 \
		libdaemon0 \
		libfftw3-single3 \
		libjq1 \
		libonig4 \
		libsamplerate0; \
	rm -rf "/var/lib/apt/lists/*"; \
	TZ='UTC' date +"%F %T" > /etc/fake-hwclock.data; \
	rm -rf /usr/share/doc /usr/share/man /usr/local/sbin/install_* /var/cache/apt/*.bin; \
	rm -f /root/.bash_history